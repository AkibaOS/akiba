//! Akiba File System (AFS) - Custom filesystem for Akiba

const gpt = @import("gpt.zig");
const heap = @import("../memory/heap.zig");
const serial = @import("../drivers/serial.zig");

const SECTOR_SIZE = 512;

pub const DirectoryEntry = extern struct {
    filename: [11]u8,
    attributes: u8,
    reserved: u8,
    creation_time_tenth: u8,
    creation_time: u16,
    creation_date: u16,
    last_access_date: u16,
    first_cluster_high: u16,
    last_modified_time: u16,
    last_modified_date: u16,
    first_cluster_low: u16,
    file_size: u32,
};

pub const ATTR_READ_ONLY: u8 = 0x01;
pub const ATTR_HIDDEN: u8 = 0x02;
pub const ATTR_SYSTEM: u8 = 0x04;
pub const ATTR_VOLUME_ID: u8 = 0x08;
pub const ATTR_DIRECTORY: u8 = 0x10;
pub const ATTR_ARCHIVE: u8 = 0x20;

pub const ListEntry = struct {
    name: [11]u8,
    is_directory: bool,
    file_size: u32,
};

pub fn AFS(comptime BlockDeviceType: type) type {
    return struct {
        device: *BlockDeviceType,
        partition_offset: u64,
        bytes_per_sector: u32,
        sectors_per_cluster: u32,
        reserved_sectors: u32,
        num_afs: u32,
        root_cluster: u32,
        afs_size: u32,
        first_data_sector: u32,
        first_afs_sector: u32,

        const Self = @This();

        pub fn init(device: *BlockDeviceType) !Self {
            serial.print("Initializing AFS (Akiba File System)...\n");

            const partition = gpt.find_first_partition(device) orelse {
                serial.print("No GPT partition found\n");
                return error.NoPartition;
            };

            var boot_sector: [SECTOR_SIZE]u8 align(16) = undefined;
            if (!device.read_sector(partition.start_lba, &boot_sector)) {
                return error.ReadFailed;
            }

            const bytes_per_sector = @as(u32, boot_sector[11]) | (@as(u32, boot_sector[12]) << 8);
            const sectors_per_cluster = @as(u32, boot_sector[13]);
            const reserved_sectors = @as(u32, boot_sector[14]) | (@as(u32, boot_sector[15]) << 8);
            const num_afs = @as(u32, boot_sector[16]);
            const afs_size = @as(u32, boot_sector[36]) |
                (@as(u32, boot_sector[37]) << 8) |
                (@as(u32, boot_sector[38]) << 16) |
                (@as(u32, boot_sector[39]) << 24);
            const root_cluster = @as(u32, boot_sector[44]) |
                (@as(u32, boot_sector[45]) << 8) |
                (@as(u32, boot_sector[46]) << 16) |
                (@as(u32, boot_sector[47]) << 24);

            serial.print("AFS (Akiba File System) detected\n");
            serial.print("Partition offset: ");
            serial.print_hex(partition.start_lba);
            serial.print("\n");
            serial.print("Bytes per sector: ");
            serial.print_hex(bytes_per_sector);
            serial.print("\n");
            serial.print("Sectors per cluster: ");
            serial.print_hex(sectors_per_cluster);
            serial.print("\n");
            serial.print("Root cluster: ");
            serial.print_hex(root_cluster);
            serial.print("\n");

            const first_afs_sector = reserved_sectors;
            const first_data_sector = reserved_sectors + (num_afs * afs_size);

            return Self{
                .device = device,
                .partition_offset = partition.start_lba,
                .bytes_per_sector = bytes_per_sector,
                .sectors_per_cluster = sectors_per_cluster,
                .reserved_sectors = reserved_sectors,
                .num_afs = num_afs,
                .root_cluster = root_cluster,
                .afs_size = afs_size,
                .first_data_sector = first_data_sector,
                .first_afs_sector = first_afs_sector,
            };
        }

        pub fn find_file(self: *Self, dir_cluster: u32, filename: []const u8) ?DirectoryEntry {
            const cluster_lba = self.partition_offset + self.first_data_sector + ((dir_cluster - 2) * self.sectors_per_cluster);

            var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
            var sector: u32 = 0;
            while (sector < self.sectors_per_cluster) : (sector += 1) {
                if (!self.device.read_sector(cluster_lba + sector, &sector_buf)) {
                    return null;
                }

                var i: usize = 0;
                while (i < SECTOR_SIZE) : (i += @sizeOf(DirectoryEntry)) {
                    const entry = @as(*DirectoryEntry, @ptrCast(@alignCast(&sector_buf[i])));

                    if (entry.filename[0] == 0x00) return null;
                    if (entry.filename[0] == 0xE5) continue;
                    if ((entry.attributes & 0x0F) == 0x0F) continue;

                    var name_match = true;
                    for (filename, 0..) |c, j| {
                        if (j >= 11) break;
                        if (entry.filename[j] != c) {
                            name_match = false;
                            break;
                        }
                    }

                    if (name_match) {
                        return entry.*;
                    }
                }
            }

            return null;
        }

        pub fn read_file(self: *Self, entry: DirectoryEntry, buffer: []u8) !usize {
            var current_cluster = (@as(u32, entry.first_cluster_high) << 16) | @as(u32, entry.first_cluster_low);
            var bytes_read: usize = 0;

            // Follow the cluster chain until we've read the whole file
            while (bytes_read < entry.file_size) {
                const cluster_lba = self.partition_offset + self.first_data_sector + ((current_cluster - 2) * self.sectors_per_cluster);

                // Read all sectors in this cluster
                var sector: u32 = 0;
                while (sector < self.sectors_per_cluster and bytes_read < entry.file_size) : (sector += 1) {
                    var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                    if (!self.device.read_sector(cluster_lba + sector, &sector_buf)) {
                        return error.ReadFailed;
                    }

                    const bytes_to_copy = @min(SECTOR_SIZE, entry.file_size - bytes_read);
                    for (sector_buf[0..bytes_to_copy], 0..) |byte, i| {
                        if (bytes_read + i >= buffer.len) break;
                        buffer[bytes_read + i] = byte;
                    }

                    bytes_read += bytes_to_copy;
                }

                // Get next cluster in chain
                const next_cluster = try self.get_next_cluster(current_cluster);
                if (next_cluster >= 0x0FFFFFF8) {
                    // End of chain
                    break;
                }
                current_cluster = next_cluster;
            }

            return bytes_read;
        }

        fn get_next_cluster(self: *Self, cluster: u32) !u32 {
            // AFS uses 4 bytes per entry
            const afs_offset = cluster * 4;
            const afs_sector = self.first_afs_sector + (afs_offset / SECTOR_SIZE);
            const entry_offset = afs_offset % SECTOR_SIZE;

            var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
            if (!self.device.read_sector(self.partition_offset + afs_sector, &sector_buf)) {
                return error.ReadFailed;
            }

            const next = @as(u32, sector_buf[entry_offset]) |
                (@as(u32, sector_buf[entry_offset + 1]) << 8) |
                (@as(u32, sector_buf[entry_offset + 2]) << 16) |
                (@as(u32, sector_buf[entry_offset + 3]) << 24);

            // Mask off top 4 bits (AFS uses 28 bits)
            return next & 0x0FFFFFFF;
        }

        pub fn cluster_to_lba(self: *Self, cluster: u32) u64 {
            return self.partition_offset + self.first_data_sector + ((cluster - 2) * self.sectors_per_cluster);
        }

        pub fn list_directory(self: *Self, cluster: u32, entries: []ListEntry) !usize {
            const cluster_lba = self.cluster_to_lba(cluster);
            var count: usize = 0;

            var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
            var sector: u32 = 0;
            while (sector < self.sectors_per_cluster) : (sector += 1) {
                if (!self.device.read_sector(cluster_lba + sector, &sector_buf)) {
                    return error.ReadFailed;
                }

                var i: usize = 0;
                while (i < SECTOR_SIZE) : (i += @sizeOf(DirectoryEntry)) {
                    const entry = @as(*DirectoryEntry, @ptrCast(@alignCast(&sector_buf[i])));

                    if (entry.filename[0] == 0x00) return count;
                    if (entry.filename[0] == 0xE5) continue;
                    if ((entry.attributes & 0x0F) == 0x0F) continue;
                    if ((entry.attributes & ATTR_VOLUME_ID) != 0) continue;

                    // Filter out . and .. entries
                    if (entry.filename[0] == '.' and entry.filename[1] == ' ') continue;
                    if (entry.filename[0] == '.' and entry.filename[1] == '.' and entry.filename[2] == ' ') continue;

                    if (count >= entries.len) return count;

                    entries[count].name = entry.filename;
                    entries[count].is_directory = (entry.attributes & ATTR_DIRECTORY) != 0;
                    entries[count].file_size = entry.file_size;
                    count += 1;
                }
            }

            return count;
        }

        pub fn find_entry(self: *Self, dir_cluster: u32, name: []const u8) ?DirectoryEntry {
            const cluster_lba = self.cluster_to_lba(dir_cluster);

            var search_name: [11]u8 = [_]u8{' '} ** 11;

            // Parse name into 8.3 format
            var dot_pos: ?usize = null;
            for (name, 0..) |c, idx| {
                if (c == '.') {
                    dot_pos = idx;
                    break;
                }
            }

            if (dot_pos) |pos| {
                const name_len = @min(pos, 8);
                const ext_start = pos + 1;
                const ext_len = @min(name.len - ext_start, 3);

                for (name[0..name_len], 0..) |c, idx| {
                    search_name[idx] = to_upper(c);
                }
                for (name[ext_start .. ext_start + ext_len], 0..) |c, idx| {
                    search_name[8 + idx] = to_upper(c);
                }
            } else {
                const name_len = @min(name.len, 11);
                for (name[0..name_len], 0..) |c, idx| {
                    search_name[idx] = to_upper(c);
                }
            }

            // Search all sectors in the cluster
            var sector: u32 = 0;
            while (sector < self.sectors_per_cluster) : (sector += 1) {
                var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                if (!self.device.read_sector(cluster_lba + sector, &sector_buf)) {
                    return null;
                }

                var i: usize = 0;
                while (i < SECTOR_SIZE) : (i += @sizeOf(DirectoryEntry)) {
                    const entry = @as(*DirectoryEntry, @ptrCast(@alignCast(&sector_buf[i])));

                    if (entry.filename[0] == 0x00) return null;
                    if (entry.filename[0] == 0xE5) continue;
                    if ((entry.attributes & 0x0F) == 0x0F) continue;
                    if ((entry.attributes & ATTR_VOLUME_ID) != 0) continue;

                    var match = true;
                    for (search_name, 0..) |c, j| {
                        if (entry.filename[j] != c) {
                            match = false;
                            break;
                        }
                    }

                    if (match) {
                        return entry.*;
                    }
                }
            }

            return null;
        }

        pub fn get_parent_cluster(self: *Self, cluster: u32) ?u32 {
            if (cluster == self.root_cluster) return self.root_cluster;

            const cluster_lba = self.cluster_to_lba(cluster);

            // Search all sectors in the cluster for .. entry
            var sector: u32 = 0;
            while (sector < self.sectors_per_cluster) : (sector += 1) {
                var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                if (!self.device.read_sector(cluster_lba + sector, &sector_buf)) {
                    return null;
                }

                var i: usize = 0;
                while (i < SECTOR_SIZE) : (i += @sizeOf(DirectoryEntry)) {
                    const entry = @as(*DirectoryEntry, @ptrCast(@alignCast(&sector_buf[i])));

                    if (entry.filename[0] == 0x00) break;
                    if (entry.filename[0] == 0xE5) continue;

                    if (entry.filename[0] == '.' and entry.filename[1] == '.' and entry.filename[2] == ' ') {
                        const parent = (@as(u32, entry.first_cluster_high) << 16) | @as(u32, entry.first_cluster_low);
                        if (parent == 0) return self.root_cluster;
                        return parent;
                    }
                }
            }

            return self.root_cluster;
        }
    };
}

fn to_upper(c: u8) u8 {
    if (c >= 'a' and c <= 'z') {
        return c - 32;
    }
    return c;
}
