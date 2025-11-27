//! Akiba File System (AFS) - Disk filesystem driver

const serial = @import("../drivers/serial.zig");
const ata = @import("../drivers/ata.zig");
const terminal = @import("../terminal.zig");

pub const BootSector = packed struct {
    jump_boot_0: u8,
    jump_boot_1: u8,
    jump_boot_2: u8,
    oem_name_0: u8,
    oem_name_1: u8,
    oem_name_2: u8,
    oem_name_3: u8,
    oem_name_4: u8,
    oem_name_5: u8,
    oem_name_6: u8,
    oem_name_7: u8,
    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sectors: u16,
    num_allocation_tables: u8,
    root_entry_count: u16,
    total_sectors_16: u16,
    media_type: u8,
    allocation_table_size_16: u16,
    sectors_per_track: u16,
    num_heads: u16,
    hidden_sectors: u32,
    total_sectors_32: u32,
    allocation_table_size_32: u32,
    ext_flags: u16,
    fs_version: u16,
    root_cluster: u32,
    fs_info: u16,
    backup_boot_sector: u16,
    reserved_0: u8,
    reserved_1: u8,
    reserved_2: u8,
    reserved_3: u8,
    reserved_4: u8,
    reserved_5: u8,
    reserved_6: u8,
    reserved_7: u8,
    reserved_8: u8,
    reserved_9: u8,
    reserved_10: u8,
    reserved_11: u8,
    drive_number: u8,
    reserved_nt: u8,
    boot_signature: u8,
    volume_id: u32,
    volume_label_0: u8,
    volume_label_1: u8,
    volume_label_2: u8,
    volume_label_3: u8,
    volume_label_4: u8,
    volume_label_5: u8,
    volume_label_6: u8,
    volume_label_7: u8,
    volume_label_8: u8,
    volume_label_9: u8,
    volume_label_10: u8,
    fs_type_0: u8,
    fs_type_1: u8,
    fs_type_2: u8,
    fs_type_3: u8,
    fs_type_4: u8,
    fs_type_5: u8,
    fs_type_6: u8,
    fs_type_7: u8,
};

pub const DirectoryEntry = packed struct {
    name_0: u8,
    name_1: u8,
    name_2: u8,
    name_3: u8,
    name_4: u8,
    name_5: u8,
    name_6: u8,
    name_7: u8,
    name_8: u8,
    name_9: u8,
    name_10: u8,
    attributes: u8,
    reserved: u8,
    creation_time_tenth: u8,
    creation_time: u16,
    creation_date: u16,
    last_access_date: u16,
    first_cluster_high: u16,
    write_time: u16,
    write_date: u16,
    first_cluster_low: u16,
    file_size: u32,
};

pub const ATTR_READ_ONLY: u8 = 0x01;
pub const ATTR_HIDDEN: u8 = 0x02;
pub const ATTR_SYSTEM: u8 = 0x04;
pub const ATTR_VOLUME_ID: u8 = 0x08;
pub const ATTR_DIRECTORY: u8 = 0x10;
pub const ATTR_ARCHIVE: u8 = 0x20;

pub const AFS = struct {
    device: *ata.BlockDevice,
    partition_start: u64,
    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sectors: u16,
    num_allocation_tables: u8,
    root_cluster: u32,
    first_data_sector: u64,
    first_allocation_table_sector: u64,
    data_sectors: u64,
    total_clusters: u64,

    pub fn init(device: *ata.BlockDevice) !AFS {
        serial.print("Initializing AFS (Akiba File System)...\r\n");

        var boot_buffer: [ata.SECTOR_SIZE]u8 = undefined;
        const partition_start_lba: u64 = 2048;

        if (!device.read_sector(partition_start_lba, &boot_buffer)) {
            serial.print("ERROR: Failed to read boot sector\r\n");
            return error.ReadFailed;
        }

        const boot = @as(*BootSector, @ptrCast(@alignCast(&boot_buffer)));

        serial.print("AFS (Akiba File System) detected\r\n");
        serial.print("Bytes per sector: ");
        serial.print_hex(boot.bytes_per_sector);
        serial.print("\r\nSectors per cluster: ");
        serial.print_hex(boot.sectors_per_cluster);
        serial.print("\r\nRoot cluster: ");
        serial.print_hex(boot.root_cluster);
        serial.print("\r\n");

        const first_allocation_table_sector = partition_start_lba + boot.reserved_sectors;
        const root_dir_sectors = ((boot.root_entry_count * 32) + (boot.bytes_per_sector - 1)) / boot.bytes_per_sector;
        const first_data_sector = partition_start_lba + boot.reserved_sectors + (boot.num_allocation_tables * boot.allocation_table_size_32) + root_dir_sectors;
        const total_sectors = if (boot.total_sectors_16 != 0) boot.total_sectors_16 else boot.total_sectors_32;
        const data_sectors = total_sectors - (first_data_sector - partition_start_lba);
        const total_clusters = data_sectors / boot.sectors_per_cluster;

        return AFS{
            .device = device,
            .partition_start = partition_start_lba,
            .bytes_per_sector = boot.bytes_per_sector,
            .sectors_per_cluster = boot.sectors_per_cluster,
            .reserved_sectors = boot.reserved_sectors,
            .num_allocation_tables = boot.num_allocation_tables,
            .root_cluster = boot.root_cluster,
            .first_data_sector = first_data_sector,
            .first_allocation_table_sector = first_allocation_table_sector,
            .data_sectors = data_sectors,
            .total_clusters = total_clusters,
        };
    }

    fn cluster_to_lba(self: *AFS, cluster: u32) u64 {
        return self.first_data_sector + @as(u64, (cluster - 2)) * @as(u64, self.sectors_per_cluster);
    }

    pub fn list_directory(self: *AFS, cluster: u32) !void {
        const lba = self.cluster_to_lba(cluster);
        var sector_buffer: [ata.SECTOR_SIZE]u8 = undefined;

        if (!self.device.read_sector(lba, &sector_buffer)) {
            return error.ReadFailed;
        }

        var i: usize = 0;
        while (i < 16) : (i += 1) {
            const entry_offset = i * 32;
            const entry = @as(*DirectoryEntry, @ptrCast(@alignCast(&sector_buffer[entry_offset])));

            if (entry.name_0 == 0x00) break;
            if (entry.name_0 == 0xE5) continue;
            if (entry.attributes == 0x0F) continue;
            if ((entry.attributes & ATTR_VOLUME_ID) != 0) continue;

            const name = get_entry_name(entry);
            for (name) |c| {
                if (c != ' ') terminal.put_char(c);
            }
            if ((entry.attributes & ATTR_DIRECTORY) != 0) {
                terminal.print(" <STACK>");
            } else {
                terminal.print(" <UNIT>");
            }
            terminal.put_char('\n');
        }
    }

    pub fn find_file(self: *AFS, cluster: u32, filename: []const u8) ?DirectoryEntry {
        const lba = self.cluster_to_lba(cluster);
        var sector_buffer: [ata.SECTOR_SIZE]u8 = undefined;

        if (!self.device.read_sector(lba, &sector_buffer)) {
            return null;
        }

        var search_name: [11]u8 = [_]u8{' '} ** 11;
        var dot_pos: ?usize = null;
        for (filename, 0..) |c, i| {
            if (c == '.') {
                dot_pos = i;
                break;
            }
        }

        if (dot_pos) |pos| {
            const name_len = @min(pos, 8);
            const ext_start = pos + 1;
            const ext_len = @min(filename.len - ext_start, 3);

            for (filename[0..name_len], 0..) |c, i| {
                search_name[i] = if (c >= 'a' and c <= 'z') c - 32 else c;
            }
            for (filename[ext_start .. ext_start + ext_len], 0..) |c, i| {
                search_name[8 + i] = if (c >= 'a' and c <= 'z') c - 32 else c;
            }
        } else {
            const name_len = @min(filename.len, 11);
            for (filename[0..name_len], 0..) |c, i| {
                search_name[i] = if (c >= 'a' and c <= 'z') c - 32 else c;
            }
        }

        var i: usize = 0;
        while (i < 16) : (i += 1) {
            const entry_offset = i * 32;
            const entry = @as(*DirectoryEntry, @ptrCast(@alignCast(&sector_buffer[entry_offset])));

            if (entry.name_0 == 0x00) break;
            if (entry.name_0 == 0xE5) continue;
            if (entry.attributes == 0x0F) continue;

            const entry_name = get_entry_name(entry);

            var match = true;
            for (search_name, 0..) |c, j| {
                if (entry_name[j] != c) {
                    match = false;
                    break;
                }
            }

            if (match) return entry.*;
        }

        return null;
    }

    pub fn read_file(self: *AFS, entry: DirectoryEntry, buffer: []u8) !usize {
        if (buffer.len < entry.file_size) {
            return error.BufferTooSmall;
        }

        const cluster = (@as(u32, entry.first_cluster_high) << 16) | @as(u32, entry.first_cluster_low);
        const lba = self.cluster_to_lba(cluster);

        var bytes_read: usize = 0;
        var remaining = entry.file_size;
        var current_lba = lba;

        while (remaining > 0) {
            var sector_buffer: [ata.SECTOR_SIZE]u8 = undefined;
            if (!self.device.read_sector(current_lba, &sector_buffer)) {
                return error.ReadFailed;
            }

            const to_copy = @min(remaining, ata.SECTOR_SIZE);
            for (sector_buffer[0..to_copy], 0..) |byte, i| {
                buffer[bytes_read + i] = byte;
            }

            bytes_read += to_copy;
            remaining -= to_copy;
            current_lba += 1;
        }

        return bytes_read;
    }
};

fn get_entry_name(entry: *const DirectoryEntry) [11]u8 {
    return [11]u8{
        entry.name_0, entry.name_1, entry.name_2,  entry.name_3,
        entry.name_4, entry.name_5, entry.name_6,  entry.name_7,
        entry.name_8, entry.name_9, entry.name_10,
    };
}
