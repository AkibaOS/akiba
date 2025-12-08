//! Akiba File System Driver
//! Case-sensitive, LFN-only filesystem

const serial = @import("../drivers/serial.zig");
const std = @import("std");

const SECTOR_SIZE = 512;

pub const AFSBootSector = extern struct {
    signature: [8]u8,
    version: u32,
    bytes_per_sector: u32,
    sectors_per_cluster: u32,
    total_clusters: u32,
    root_cluster: u32,
    alloc_table_sector: u32,
    alloc_table_size: u32,
    data_area_sector: u32,
    reserved: [466]u8,
    boot_signature: u16,
};

pub const AFSDirEntry = extern struct {
    entry_type: u8,
    name_len: u8,
    name: [255]u8,
    attributes: u8,
    reserved: u16,
    first_cluster: u32,
    file_size: u64,
    created_time: u64,
    modified_time: u64,
};

pub const ENTRY_TYPE_END: u8 = 0x00;
pub const ENTRY_TYPE_FILE: u8 = 0x01;
pub const ENTRY_TYPE_DIR: u8 = 0x02;

pub const ATTR_DIRECTORY: u8 = 0x10;

pub const ListEntry = struct {
    name: [256]u8,
    name_len: usize,
    is_directory: bool,
    file_size: u32,
};

pub fn AFS(comptime BlockDeviceType: type) type {
    return struct {
        device: *BlockDeviceType,
        partition_offset: u64,
        bytes_per_sector: u32,
        sectors_per_cluster: u32,
        total_clusters: u32,
        root_cluster: u32,
        alloc_table_sector: u32,
        alloc_table_size: u32,
        data_area_sector: u32,
        parent_cache: [256]ParentEntry,
        parent_cache_count: usize,

        const Self = @This();

        const ParentEntry = struct {
            cluster: u32,
            parent: u32,
        };

        pub fn init(device: *BlockDeviceType, partition_offset: u64) !Self {
            serial.print("Initializing Akiba File System...\n");

            var boot_sector: [SECTOR_SIZE]u8 align(16) = undefined;
            if (!device.read_sector(partition_offset, &boot_sector)) {
                return error.ReadFailed;
            }

            const boot = @as(*AFSBootSector, @ptrCast(@alignCast(&boot_sector)));

            if (!std.mem.eql(u8, boot.signature[0..8], "AKIBAFS!")) {
                serial.print("ERROR: Invalid AFS signature\n");
                return error.InvalidFilesystem;
            }

            if (boot.boot_signature != 0xAA55) {
                serial.print("ERROR: Invalid boot signature\n");
                return error.InvalidFilesystem;
            }

            serial.print("AFS detected\n");
            serial.print("Version: ");
            serial.print_hex(boot.version);
            serial.print("\n");
            serial.print("Total clusters: ");
            serial.print_hex(boot.total_clusters);
            serial.print("\n");
            serial.print("Root cluster: ");
            serial.print_hex(boot.root_cluster);
            serial.print("\n");

            return Self{
                .device = device,
                .partition_offset = partition_offset,
                .bytes_per_sector = boot.bytes_per_sector,
                .sectors_per_cluster = boot.sectors_per_cluster,
                .total_clusters = boot.total_clusters,
                .root_cluster = boot.root_cluster,
                .alloc_table_sector = boot.alloc_table_sector,
                .alloc_table_size = boot.alloc_table_size,
                .data_area_sector = boot.data_area_sector,
                .parent_cache = undefined,
                .parent_cache_count = 0,
            };
        }

        pub fn find_file(self: *Self, dir_cluster: u32, filename: []const u8) ?AFSDirEntry {
            var cluster = dir_cluster;

            while (cluster >= 2 and cluster < 0xFFFFFFFF) {
                const cluster_lba = self.partition_offset + self.data_area_sector + (cluster - 2);

                var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                if (!self.device.read_sector(cluster_lba, &sector_buf)) {
                    return null;
                }

                const entry = @as(*AFSDirEntry, @ptrCast(@alignCast(&sector_buf[0])));

                if (entry.entry_type == ENTRY_TYPE_END) {
                    return null;
                }

                if (entry.entry_type == ENTRY_TYPE_FILE or entry.entry_type == ENTRY_TYPE_DIR) {
                    const entry_name = entry.name[0..entry.name_len];

                    if (std.mem.eql(u8, entry_name, filename)) {
                        if (entry.entry_type == ENTRY_TYPE_DIR) {
                            self.cache_parent(entry.first_cluster, dir_cluster);
                        }
                        return entry.*;
                    }
                }

                cluster = self.get_next_cluster(cluster) catch return null;
            }

            return null;
        }

        fn cache_parent(self: *Self, child: u32, parent: u32) void {
            for (self.parent_cache[0..self.parent_cache_count]) |*e| {
                if (e.cluster == child) {
                    e.parent = parent;
                    return;
                }
            }

            if (self.parent_cache_count < self.parent_cache.len) {
                self.parent_cache[self.parent_cache_count] = .{
                    .cluster = child,
                    .parent = parent,
                };
                self.parent_cache_count += 1;
            }
        }

        pub fn read_file(self: *Self, entry: AFSDirEntry, buffer: []u8) !usize {
            var cluster = entry.first_cluster;
            var bytes_read: usize = 0;

            while (cluster >= 2 and cluster < 0xFFFFFFFF) {
                const cluster_lba = self.partition_offset + self.data_area_sector + (cluster - 2);

                var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                if (!self.device.read_sector(cluster_lba, &sector_buf)) {
                    return error.ReadFailed;
                }

                const bytes_to_copy = @min(SECTOR_SIZE, entry.file_size - bytes_read);
                for (sector_buf[0..bytes_to_copy], 0..) |byte, i| {
                    if (bytes_read + i >= buffer.len) break;
                    buffer[bytes_read + i] = byte;
                }

                bytes_read += bytes_to_copy;
                if (bytes_read >= entry.file_size) break;

                cluster = try self.get_next_cluster(cluster);
            }

            return bytes_read;
        }

        fn get_next_cluster(self: *Self, cluster: u32) !u32 {
            const table_entry_offset = cluster * 4;
            const table_sector = self.partition_offset + self.alloc_table_sector + (table_entry_offset / self.bytes_per_sector);
            const entry_offset = table_entry_offset % self.bytes_per_sector;

            var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
            if (!self.device.read_sector(table_sector, &sector_buf)) {
                return error.ReadFailed;
            }

            const next_cluster = @as(u32, sector_buf[entry_offset]) |
                (@as(u32, sector_buf[entry_offset + 1]) << 8) |
                (@as(u32, sector_buf[entry_offset + 2]) << 16) |
                (@as(u32, sector_buf[entry_offset + 3]) << 24);

            return next_cluster;
        }

        pub fn cluster_to_lba(self: *Self, cluster: u32) u64 {
            return self.partition_offset + self.data_area_sector + (cluster - 2);
        }

        pub fn list_directory(self: *Self, cluster_arg: u32, entries: []ListEntry) !usize {
            var cluster = cluster_arg;
            var count: usize = 0;

            while (cluster >= 2 and cluster < 0xFFFFFFFF) {
                const cluster_lba = self.cluster_to_lba(cluster);

                var sector_buf: [SECTOR_SIZE]u8 align(16) = undefined;
                if (!self.device.read_sector(cluster_lba, &sector_buf)) {
                    return error.ReadFailed;
                }

                const entry = @as(*AFSDirEntry, @ptrCast(@alignCast(&sector_buf[0])));

                if (entry.entry_type == ENTRY_TYPE_END) {
                    return count;
                }

                if (entry.entry_type == ENTRY_TYPE_FILE or entry.entry_type == ENTRY_TYPE_DIR) {
                    if (count >= entries.len) return count;

                    for (entry.name[0..entry.name_len], 0..) |c, i| {
                        entries[count].name[i] = c;
                    }
                    entries[count].name_len = entry.name_len;
                    entries[count].is_directory = (entry.entry_type == ENTRY_TYPE_DIR);
                    entries[count].file_size = @truncate(entry.file_size);
                    count += 1;
                }

                cluster = self.get_next_cluster(cluster) catch return count;
            }

            return count;
        }

        pub fn read_file_by_path(self: *Self, path: []const u8, buffer: []u8) !usize {
            var cluster = self.root_cluster;
            var start: usize = 0;
            var i: usize = 0;

            if (path.len > 0 and path[0] == '/') {
                start = 1;
                i = 1;
            }

            while (i <= path.len) : (i += 1) {
                const is_end = (i == path.len);
                const is_slash = !is_end and path[i] == '/';

                if (is_slash or is_end) {
                    if (i > start) {
                        const component = path[start..i];

                        const entry = self.find_file(cluster, component) orelse {
                            serial.print("ERROR: Path component not found: ");
                            serial.print(component);
                            serial.print("\n");
                            return error.NotFound;
                        };

                        if (is_end) {
                            if (entry.entry_type != ENTRY_TYPE_FILE) {
                                return error.NotAFile;
                            }
                            return self.read_file(entry, buffer);
                        } else {
                            if (entry.entry_type != ENTRY_TYPE_DIR) {
                                return error.NotADirectory;
                            }
                            cluster = entry.first_cluster;
                        }
                    }
                    start = i + 1;
                }
            }

            return error.InvalidPath;
        }

        pub fn get_parent_cluster(self: *Self, cluster: u32) ?u32 {
            if (cluster == self.root_cluster) return self.root_cluster;

            for (self.parent_cache[0..self.parent_cache_count]) |entry| {
                if (entry.cluster == cluster) {
                    return entry.parent;
                }
            }

            return null;
        }
    };
}
