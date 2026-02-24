//! mkafsdisk: Creates a bootable Akiba disk image with GPT partitioning, ESP and AFS partitions

const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const AFSBootSector = extern struct {
    signature: [8]u8,
    version: u32,
    bytes_per_sector: u32,
    sectors_per_cluster: u32,
    total_clusters: u32,
    root_cluster: u32,
    alloc_table_sector: u32,
    alloc_table_size: u32,
    data_area_sector: u32,
    used_clusters: u32,
    reserved: [462]u8,
    boot_signature: u16,
};

const AFSDirEntry = extern struct {
    entry_type: u8,
    name_len: u8,
    name: [255]u8,
    owner_name_len: u8,
    owner_name: [64]u8,
    permission_type: u8, // 1=OA, 2=WA, 3=WR
    reserved: u8,
    first_cluster: u32,
    file_size: u64,
    created_time: u64,
    modified_time: u64,
};

const ENTRY_TYPE_END: u8 = 0x00;
const ENTRY_TYPE_FILE: u8 = 0x01;
const ENTRY_TYPE_DIR: u8 = 0x02;

const PERM_OWNER: u8 = 1; // OA - Owner All
const PERM_WORLD: u8 = 2; // WA - World All
const PERM_READ_ONLY: u8 = 3; // WR - World Read

const FATDateTime = struct {
    date: u16,
    time: u16,
};

const FileEntry = struct {
    name: [11]u8,
    original_name: [256]u8,
    original_name_len: usize,
    is_directory: bool,
    size: u64,
    start_cluster: u32,
};

const ClusterAllocator = struct {
    next_cluster: u32,
    allocations: std.ArrayListUnmanaged(ClusterChain),
    allocator: std.mem.Allocator,

    const ClusterChain = struct {
        start: u32,
        clusters: []u32,
    };

    fn init(start_cluster: u32, allocator: std.mem.Allocator) ClusterAllocator {
        return .{
            .next_cluster = start_cluster + 1,
            .allocations = .{},
            .allocator = allocator,
        };
    }

    fn allocate(self: *ClusterAllocator, count: u32) !u32 {
        const start = self.next_cluster;
        var clusters = try self.allocator.alloc(u32, count);
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            clusters[i] = self.next_cluster;
            self.next_cluster += 1;
        }
        try self.allocations.append(self.allocator, ClusterChain{ .start = start, .clusters = clusters });
        return start;
    }

    fn deinit(self: *ClusterAllocator) void {
        for (self.allocations.items) |chain| {
            self.allocator.free(chain.clusters);
        }
        self.allocations.deinit(self.allocator);
    }
};

var global_file_count: usize = 0;
var global_total_files: usize = 0;

fn printProgress(current: usize, total: usize, filename: []const u8) void {
    std.debug.print("\r  [{d}/{d}] {s}", .{ current, total, filename });
    var i: usize = filename.len;
    while (i < 60) : (i += 1) {
        std.debug.print(" ", .{});
    }
    if (current == total) {
        std.debug.print("\n", .{});
    }
}

fn getCurrentFATDateTime() FATDateTime {
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(std.time.timestamp()) };
    const day_seconds = epoch.getDaySeconds();
    const epoch_day = epoch.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    const dos_year: u16 = @intCast(year_day.year - 1980);
    const dos_month: u16 = @intCast(month_day.month.numeric());
    const dos_day: u16 = @intCast(month_day.day_index + 1);

    const hour: u16 = @intCast(day_seconds.getHoursIntoDay());
    const minute: u16 = @intCast(day_seconds.getMinutesIntoHour());
    const second: u16 = @intCast(day_seconds.getSecondsIntoMinute() / 2);

    return FATDateTime{
        .date = (dos_year << 9) | (dos_month << 5) | dos_day,
        .time = (hour << 11) | (minute << 5) | second,
    };
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 4) {
        std.debug.print("Usage: {s} <source_dir> <output_image> <size_mb>\n", .{args[0]});
        return error.InvalidArgs;
    }

    const source_dir = args[1];
    const output_image = args[2];
    const size_mb = try std.fmt.parseInt(u32, args[3], 10);

    std.debug.print("Creating AFS disk image:\n", .{});
    std.debug.print("  Source: {s}\n", .{source_dir});
    std.debug.print("  Output: {s}\n", .{output_image});
    std.debug.print("  Size: {d}MB\n", .{size_mb});

    try createDiskImage(allocator, source_dir, output_image, size_mb);

    std.debug.print("✓ AFS disk image created successfully\n", .{});
}

fn createDiskImage(allocator: mem.Allocator, source_dir: []const u8, output_path: []const u8, size_mb: u32) !void {
    const size_bytes = @as(u64, size_mb) * 1024 * 1024;
    const total_sectors = @as(u32, @intCast(size_bytes / 512));
    const esp_size_sectors = 33 * 1024 * 2;
    const esp_start = 2048;
    const afs_start = esp_start + esp_size_sectors;
    const afs_sectors = total_sectors - afs_start;

    std.debug.print("  ESP: sectors {d}-{d}\n", .{ esp_start, afs_start - 1 });
    std.debug.print("  AFS: sectors {d}-{d}\n", .{ afs_start, total_sectors - 1 });

    const file = try fs.cwd().createFile(output_path, .{ .read = true });
    defer file.close();
    try file.setEndPos(size_bytes);

    try writeMBR(file, total_sectors);
    try writeGPT(file, esp_start, afs_start, total_sectors);
    try createESPWithGRUB(file, source_dir, esp_start, esp_size_sectors);

    var cluster_alloc = ClusterAllocator.init(2, allocator);
    defer cluster_alloc.deinit();
    try createAFS(allocator, file, source_dir, afs_start, afs_sectors, &cluster_alloc);

    std.debug.print("✓ Two-partition disk created\n", .{});
}

fn writeMBR(file: fs.File, total_sectors: u32) !void {
    var mbr: [512]u8 = [_]u8{0} ** 512;
    mbr[0x1BE + 4] = 0xEE;
    mem.writeInt(u32, mbr[0x1BE + 8 ..][0..4], 1, .little);
    mem.writeInt(u32, mbr[0x1BE + 12 ..][0..4], total_sectors - 1, .little);
    mbr[510] = 0x55;
    mbr[511] = 0xAA;
    try file.seekTo(0);
    try file.writeAll(&mbr);
}

fn calculateCRC32(data: []const u8) u32 {
    var crc: u32 = 0xFFFFFFFF;
    for (data) |byte| {
        var temp = (crc ^ byte) & 0xFF;
        var i: u8 = 0;
        while (i < 8) : (i += 1) {
            if (temp & 1 != 0) {
                temp = (temp >> 1) ^ 0xEDB88320;
            } else {
                temp = temp >> 1;
            }
        }
        crc = (crc >> 8) ^ temp;
    }
    return ~crc;
}

fn writeGPT(file: fs.File, esp_start: u32, afs_start: u32, total_sectors: u32) !void {
    var partition_array: [16384]u8 = [_]u8{0} ** 16384;

    var esp_entry: [128]u8 = [_]u8{0} ** 128;
    const efi_guid = [_]u8{ 0x28, 0x73, 0x2A, 0xC1, 0x1F, 0xF8, 0xD2, 0x11, 0xBA, 0x4B, 0x00, 0xA0, 0xC9, 0x3E, 0xC9, 0x3B };
    mem.copyForwards(u8, esp_entry[0..16], &efi_guid);
    const part_guid = [_]u8{ 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 };
    mem.copyForwards(u8, esp_entry[16..32], &part_guid);
    mem.writeInt(u64, esp_entry[32..40], esp_start, .little);
    mem.writeInt(u64, esp_entry[40..48], afs_start - 1, .little);
    mem.writeInt(u64, esp_entry[48..56], 0x0000000000000001, .little);
    const esp_name = "EFI System";
    for (esp_name, 0..) |c, i| {
        esp_entry[56 + i * 2] = c;
    }
    mem.copyForwards(u8, partition_array[0..128], &esp_entry);

    var afs_entry: [128]u8 = [_]u8{0} ** 128;
    const afs_guid = [_]u8{ 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6, 0x07, 0x18, 0x29, 0x3A, 0x4B, 0x5C, 0x6D, 0x7E, 0x8F, 0x90 };
    mem.copyForwards(u8, afs_entry[0..16], &afs_guid);
    const afs_part_guid = [_]u8{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA };
    mem.copyForwards(u8, afs_entry[16..32], &afs_part_guid);
    mem.writeInt(u64, afs_entry[32..40], afs_start, .little);
    mem.writeInt(u64, afs_entry[40..48], total_sectors - 1, .little);
    const afs_name = "Akiba FS";
    for (afs_name, 0..) |c, i| {
        afs_entry[56 + i * 2] = c;
    }
    mem.copyForwards(u8, partition_array[128..256], &afs_entry);

    const partition_crc = calculateCRC32(partition_array[0..]);

    var gpt_header: [512]u8 = [_]u8{0} ** 512;
    mem.copyForwards(u8, gpt_header[0..8], "EFI PART");
    mem.writeInt(u32, gpt_header[8..12], 0x00010000, .little);
    mem.writeInt(u32, gpt_header[12..16], 92, .little);
    mem.writeInt(u64, gpt_header[24..32], 1, .little);
    mem.writeInt(u64, gpt_header[32..40], @as(u64, total_sectors) - 1, .little);
    mem.writeInt(u64, gpt_header[40..48], 34, .little);
    mem.writeInt(u64, gpt_header[48..56], @as(u64, total_sectors) - 34, .little);
    const disk_guid = [_]u8{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF };
    mem.copyForwards(u8, gpt_header[56..72], &disk_guid);
    mem.writeInt(u64, gpt_header[72..80], 2, .little);
    mem.writeInt(u32, gpt_header[80..84], 128, .little);
    mem.writeInt(u32, gpt_header[84..88], 128, .little);
    mem.writeInt(u32, gpt_header[88..92], partition_crc, .little);

    const header_crc = calculateCRC32(gpt_header[0..92]);
    mem.writeInt(u32, gpt_header[16..20], header_crc, .little);

    try file.seekTo(512);
    try file.writeAll(&gpt_header);

    try file.seekTo(1024);
    try file.writeAll(&partition_array);
}

fn copyFileToFAT(
    file: fs.File,
    source_path: []const u8,
    start_cluster: u32,
    data_start: u32,
    fat_data: []u8,
    allocator: mem.Allocator,
) !u32 {
    const source_file = try fs.cwd().openFile(source_path, .{});
    defer source_file.close();

    const file_size = try source_file.getEndPos();
    const num_clusters: u32 = @intCast((file_size + 511) / 512);

    var cluster_idx: u32 = 0;
    while (cluster_idx < num_clusters) : (cluster_idx += 1) {
        var buffer: [512]u8 = [_]u8{0} ** 512;
        _ = try source_file.read(&buffer);

        const cluster_num: u32 = start_cluster + cluster_idx;
        const cluster_lba = data_start + (cluster_num - 2);
        try file.seekTo(@as(u64, cluster_lba) * 512);
        try file.writeAll(&buffer);

        const fat_entry_offset = cluster_num * 4;
        const next_cluster: u32 = if (cluster_idx == num_clusters - 1) 0x0FFFFFFF else (cluster_num + 1);
        mem.writeInt(u32, fat_data[fat_entry_offset..][0..4], next_cluster, .little);
    }

    _ = allocator;
    return num_clusters;
}

fn makeShortName(long_name: []const u8, name_buf: *[11]u8, is_directory: bool) void {
    @memset(name_buf, ' ');

    var dot_pos: ?usize = null;
    for (long_name, 0..) |c, i| {
        if (c == '.') dot_pos = i;
    }

    if (is_directory) {
        const len = @min(long_name.len, 11);
        for (0..len) |i| {
            name_buf[i] = std.ascii.toUpper(long_name[i]);
        }
    } else if (dot_pos) |pos| {
        const base_len = @min(pos, 8);
        for (0..base_len) |i| {
            name_buf[i] = std.ascii.toUpper(long_name[i]);
        }
        const ext_start = pos + 1;
        const ext_len = @min(long_name.len - ext_start, 3);
        for (0..ext_len) |i| {
            name_buf[8 + i] = std.ascii.toUpper(long_name[ext_start + i]);
        }
    } else {
        const len = @min(long_name.len, 8);
        for (0..len) |i| {
            name_buf[i] = std.ascii.toUpper(long_name[i]);
        }
    }
}

fn copyDirectoryToFAT(
    disk_file: fs.File,
    source_dir: []const u8,
    dir_cluster: u32,
    data_start: u32,
    current_cluster: *u32,
    fat_data: []u8,
    datetime: FATDateTime,
    allocator: mem.Allocator,
) !void {
    var dir = try fs.cwd().openDir(source_dir, .{ .iterate = true });
    defer dir.close();

    var entries: [256]FileEntry = undefined;
    var entry_count: usize = 0;

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.name[0] == '.') continue;
        if (entry_count >= 256) return error.TooManyEntries;

        var file_entry: *FileEntry = &entries[entry_count];
        makeShortName(entry.name, &file_entry.name, entry.kind == .directory);
        file_entry.is_directory = entry.kind == .directory;

        const name_len = @min(entry.name.len, 255);
        @memcpy(file_entry.original_name[0..name_len], entry.name[0..name_len]);
        file_entry.original_name_len = name_len;

        if (entry.kind == .directory) {
            file_entry.size = 0;
            file_entry.start_cluster = current_cluster.*;
            current_cluster.* += 1;
        } else {
            const file_path = try fs.path.join(allocator, &[_][]const u8{ source_dir, entry.name });
            defer allocator.free(file_path);

            const file = try fs.cwd().openFile(file_path, .{});
            defer file.close();
            file_entry.size = try file.getEndPos();
            file_entry.start_cluster = current_cluster.*;

            const num_clusters = try copyFileToFAT(disk_file, file_path, file_entry.start_cluster, data_start, fat_data, allocator);
            current_cluster.* += num_clusters;
        }

        entry_count += 1;
    }

    const entries_slice = entries[0..entry_count];

    const entries_per_sector = 512 / 32;
    const sectors_needed = ((entry_count + 2) + entries_per_sector - 1) / entries_per_sector;

    var dir_buffer = try allocator.alloc(u8, sectors_needed * 512);
    defer allocator.free(dir_buffer);
    @memset(dir_buffer, 0);

    mem.copyForwards(u8, dir_buffer[0..11], ".          ");
    dir_buffer[11] = 0x10;
    mem.writeInt(u16, dir_buffer[14..16], datetime.time, .little);
    mem.writeInt(u16, dir_buffer[16..18], datetime.date, .little);
    mem.writeInt(u16, dir_buffer[26..28], @intCast(dir_cluster), .little);

    mem.copyForwards(u8, dir_buffer[32..43], "..         ");
    dir_buffer[43] = 0x10;
    mem.writeInt(u16, dir_buffer[46..48], datetime.time, .little);
    mem.writeInt(u16, dir_buffer[48..50], datetime.date, .little);
    mem.writeInt(u16, dir_buffer[58..60], 0, .little);

    for (entries_slice, 0..) |entry, i| {
        const offset = (i + 2) * 32;
        mem.copyForwards(u8, dir_buffer[offset..][0..11], &entry.name);
        dir_buffer[offset + 11] = if (entry.is_directory) 0x10 else 0x20;
        mem.writeInt(u16, dir_buffer[offset + 14 ..][0..2], datetime.time, .little);
        mem.writeInt(u16, dir_buffer[offset + 16 ..][0..2], datetime.date, .little);
        mem.writeInt(u16, dir_buffer[offset + 26 ..][0..2], @intCast(entry.start_cluster), .little);
        mem.writeInt(u32, dir_buffer[offset + 28 ..][0..4], @intCast(entry.size), .little);
    }

    const dir_lba = data_start + (dir_cluster - 2);
    try disk_file.seekTo(@as(u64, dir_lba) * 512);
    try disk_file.writeAll(dir_buffer);

    for (0..sectors_needed) |i| {
        const cluster_num: u32 = dir_cluster + @as(u32, @intCast(i));
        const fat_offset = cluster_num * 4;
        const next: u32 = if (i == sectors_needed - 1) 0x0FFFFFFF else (cluster_num + 1);
        mem.writeInt(u32, fat_data[fat_offset..][0..4], next, .little);
    }

    for (entries_slice) |entry| {
        if (entry.is_directory) {
            const original_name = entry.original_name[0..entry.original_name_len];
            const subdir_path = try fs.path.join(allocator, &[_][]const u8{ source_dir, original_name });
            defer allocator.free(subdir_path);

            try copyDirectoryToFAT(disk_file, subdir_path, entry.start_cluster, data_start, current_cluster, fat_data, datetime, allocator);
        }
    }
}

fn createESPWithGRUB(file: fs.File, source_dir: []const u8, esp_start: u32, esp_sectors: u32) !void {
    std.debug.print("  Creating ESP with GRUB...\n", .{});

    const sectors_per_cluster: u32 = 1;
    const cluster_size: u32 = 512;

    var boot: [512]u8 = [_]u8{0} ** 512;
    boot[0] = 0xEB;
    boot[1] = 0x58;
    boot[2] = 0x90;
    mem.copyForwards(u8, boot[3..11], "MSWIN4.1");
    mem.writeInt(u16, boot[11..13], 512, .little);
    boot[13] = 1;
    mem.writeInt(u16, boot[14..16], 32, .little);
    boot[16] = 2;
    mem.writeInt(u16, boot[17..19], 0, .little);
    mem.writeInt(u16, boot[19..21], 0, .little);
    boot[21] = 0xF8;
    mem.writeInt(u16, boot[22..24], 0, .little);
    mem.writeInt(u16, boot[24..26], 63, .little);
    mem.writeInt(u16, boot[26..28], 255, .little);
    mem.writeInt(u32, boot[28..32], 0, .little);
    mem.writeInt(u32, boot[32..36], esp_sectors, .little);

    const reserved_sectors: u32 = 32;
    const num_fats: u32 = 2;
    const bytes_per_fat_entry: u32 = 4;

    const available = esp_sectors - reserved_sectors;
    const fat_size = (bytes_per_fat_entry * available + 511 * sectors_per_cluster) /
        (512 * sectors_per_cluster + bytes_per_fat_entry * num_fats);

    const data_area = available - (fat_size * num_fats);
    const total_clusters = data_area / sectors_per_cluster;

    std.debug.print("  FAT32: fat_size={d} sectors, clusters={d}\n", .{ fat_size, total_clusters });

    mem.writeInt(u32, boot[36..40], fat_size, .little);
    mem.writeInt(u16, boot[40..42], 0, .little);
    mem.writeInt(u16, boot[42..44], 0, .little);
    mem.writeInt(u32, boot[44..48], 2, .little);
    mem.writeInt(u16, boot[48..50], 1, .little);
    mem.writeInt(u16, boot[50..52], 6, .little);
    boot[64] = 0x80;
    boot[66] = 0x29;
    mem.writeInt(u32, boot[67..71], 0x12345678, .little);
    mem.copyForwards(u8, boot[71..82], "AKIBA      ");
    mem.copyForwards(u8, boot[82..90], "FAT32   ");
    boot[510] = 0x55;
    boot[511] = 0xAA;

    try file.seekTo(@as(u64, esp_start) * 512);
    try file.writeAll(&boot);

    var fsinfo: [512]u8 = [_]u8{0} ** 512;
    mem.writeInt(u32, fsinfo[0..4], 0x41615252, .little);
    mem.writeInt(u32, fsinfo[484..488], 0x61417272, .little);
    mem.writeInt(u32, fsinfo[488..492], 0xFFFFFFFF, .little);
    mem.writeInt(u32, fsinfo[492..496], 0xFFFFFFFF, .little);
    mem.writeInt(u32, fsinfo[508..512], 0xAA550000, .little);
    try file.seekTo((@as(u64, esp_start) + 1) * 512);
    try file.writeAll(&fsinfo);
    try file.seekTo((@as(u64, esp_start) + 6) * 512);
    try file.writeAll(&boot);

    const fat_offset = esp_start + 32;
    var fat_data = try std.heap.page_allocator.alloc(u8, @as(usize, fat_size) * 512);
    defer std.heap.page_allocator.free(fat_data);
    @memset(fat_data, 0);
    mem.writeInt(u32, fat_data[0..4], 0x0FFFFFF8, .little);
    mem.writeInt(u32, fat_data[4..8], 0x0FFFFFFF, .little);
    mem.writeInt(u32, fat_data[8..12], 0x0FFFFFFF, .little);

    const data_start = esp_start + 32 + (fat_size * 2);
    const datetime = getCurrentFATDateTime();

    const efi_path = try fs.path.join(std.heap.page_allocator, &[_][]const u8{ source_dir, "EFI", "BOOT", "BOOTX64.EFI" });
    defer std.heap.page_allocator.free(efi_path);
    const grub_file = fs.cwd().openFile(efi_path, .{}) catch {
        std.debug.print("  WARNING: GRUB not found\n", .{});
        return;
    };
    defer grub_file.close();
    const grub_size: u32 = @intCast(try grub_file.getEndPos());
    const grub_clusters: u32 = (grub_size + cluster_size - 1) / cluster_size;
    std.debug.print("  Copying GRUB ({d} bytes, {d} clusters)\n", .{ grub_size, grub_clusters });

    const grub_start_cluster: u32 = 3;
    var cluster_idx: u32 = 0;
    while (cluster_idx < grub_clusters) : (cluster_idx += 1) {
        var buffer: [512]u8 = [_]u8{0} ** 512;
        const bytes_read = try grub_file.read(&buffer);
        if (bytes_read == 0) break;

        const cluster_num = grub_start_cluster + cluster_idx;
        const cluster_lba = data_start + (cluster_num - 2);
        try file.seekTo(@as(u64, cluster_lba) * 512);
        try file.writeAll(&buffer);

        const fat_entry_offset = cluster_num * 4;
        const next_cluster = if (cluster_idx == grub_clusters - 1) 0x0FFFFFFF else (cluster_num + 1);
        mem.writeInt(u32, fat_data[fat_entry_offset..][0..4], next_cluster, .little);
    }

    var current_cluster: u32 = grub_start_cluster + grub_clusters;

    const root_cluster_lba = data_start;
    const efi_cluster = current_cluster;
    current_cluster += 1;
    const boot_cluster = current_cluster;
    current_cluster += 1;

    var root_dir: [512]u8 = [_]u8{0} ** 512;
    mem.copyForwards(u8, root_dir[0..11], "EFI        ");
    root_dir[11] = 0x10;
    mem.writeInt(u16, root_dir[14..16], datetime.time, .little);
    mem.writeInt(u16, root_dir[16..18], datetime.date, .little);
    mem.writeInt(u16, root_dir[26..28], @intCast(efi_cluster), .little);

    mem.copyForwards(u8, root_dir[32..43], "boot       ");
    root_dir[43] = 0x10;
    mem.writeInt(u16, root_dir[46..48], datetime.time, .little);
    mem.writeInt(u16, root_dir[48..50], datetime.date, .little);
    mem.writeInt(u16, root_dir[58..60], @intCast(boot_cluster), .little);

    try file.seekTo(@as(u64, root_cluster_lba) * 512);
    try file.writeAll(&root_dir);
    mem.writeInt(u32, fat_data[2 * 4 ..][0..4], 0x0FFFFFFF, .little);

    const boot_subdir_cluster = current_cluster;
    current_cluster += 1;

    var efi_dir: [512]u8 = [_]u8{0} ** 512;
    mem.copyForwards(u8, efi_dir[0..11], ".          ");
    efi_dir[11] = 0x10;
    mem.writeInt(u16, efi_dir[26..28], @intCast(efi_cluster), .little);
    mem.copyForwards(u8, efi_dir[32..43], "..         ");
    efi_dir[43] = 0x10;
    mem.writeInt(u16, efi_dir[58..60], 0, .little);
    mem.copyForwards(u8, efi_dir[64..75], "BOOT       ");
    efi_dir[75] = 0x10;
    mem.writeInt(u16, efi_dir[90..92], @intCast(boot_subdir_cluster), .little);

    const efi_cluster_lba = data_start + (efi_cluster - 2);
    try file.seekTo(@as(u64, efi_cluster_lba) * 512);
    try file.writeAll(&efi_dir);
    mem.writeInt(u32, fat_data[efi_cluster * 4 ..][0..4], 0x0FFFFFFF, .little);

    var boot_dir: [512]u8 = [_]u8{0} ** 512;
    mem.copyForwards(u8, boot_dir[0..11], ".          ");
    boot_dir[11] = 0x10;
    mem.writeInt(u16, boot_dir[26..28], @intCast(boot_subdir_cluster), .little);
    mem.copyForwards(u8, boot_dir[32..43], "..         ");
    boot_dir[43] = 0x10;
    mem.writeInt(u16, boot_dir[58..60], @intCast(efi_cluster), .little);
    mem.copyForwards(u8, boot_dir[64..75], "BOOTX64 EFI");
    boot_dir[75] = 0x20;
    mem.writeInt(u16, boot_dir[90..92], @intCast(grub_start_cluster), .little);
    mem.writeInt(u32, boot_dir[92..96], @intCast(grub_size), .little);

    const boot_subdir_lba = data_start + (boot_subdir_cluster - 2);
    try file.seekTo(@as(u64, boot_subdir_lba) * 512);
    try file.writeAll(&boot_dir);
    mem.writeInt(u32, fat_data[boot_subdir_cluster * 4 ..][0..4], 0x0FFFFFFF, .little);

    const boot_source = try fs.path.join(std.heap.page_allocator, &[_][]const u8{ source_dir, "boot" });
    defer std.heap.page_allocator.free(boot_source);

    std.debug.print("  Copying boot directory recursively...\n", .{});
    try copyDirectoryToFAT(file, boot_source, boot_cluster, data_start, &current_cluster, fat_data, datetime, std.heap.page_allocator);

    try file.seekTo(@as(u64, fat_offset) * 512);
    try file.writeAll(fat_data);
    try file.seekTo((@as(u64, fat_offset) + fat_size) * 512);
    try file.writeAll(fat_data);

    std.debug.print("  ESP created successfully\n", .{});
}

fn createAFS(allocator: mem.Allocator, file: fs.File, source_dir: []const u8, partition_start: u32, partition_sectors: u32, cluster_alloc: *ClusterAllocator) !void {
    const sectors_per_cluster = 1;
    const total_clusters = partition_sectors / sectors_per_cluster;
    const alloc_table_size = (total_clusters * 4 + 511) / 512;
    const data_area_start = 1 + alloc_table_size;
    const root_cluster = try cluster_alloc.allocate(10);

    std.debug.print("  Creating AFS partition...\n", .{});
    std.debug.print("  Total clusters: {d}\n", .{total_clusters});

    var boot = std.mem.zeroes(AFSBootSector);
    mem.copyForwards(u8, &boot.signature, "AKIBAFS!");
    boot.version = 0x00020000;
    boot.bytes_per_sector = 512;
    boot.sectors_per_cluster = sectors_per_cluster;
    boot.total_clusters = total_clusters;
    boot.root_cluster = root_cluster;
    boot.alloc_table_sector = 1;
    boot.alloc_table_size = alloc_table_size;
    boot.data_area_sector = data_area_start;
    boot.used_clusters = 0;
    boot.boot_signature = 0xAA55;

    try file.seekTo(@as(u64, partition_start) * 512);
    try file.writeAll(mem.asBytes(&boot));
    try initAllocationTable(file, partition_start, alloc_table_size);

    global_total_files = try countFiles(source_dir);
    global_file_count = 0;
    std.debug.print("  Files to copy: {d}\n", .{global_total_files});

    try copyDirectoryAFS(allocator, file, source_dir, partition_start, data_area_start, cluster_alloc, root_cluster);

    try writeAllocationTable(file, partition_start, alloc_table_size, cluster_alloc);
    // Update used_clusters in boot sector
    boot.used_clusters = cluster_alloc.next_cluster - 2; // Subtract reserved clusters
    try file.seekTo(@as(u64, partition_start) * 512);
    try file.writeAll(mem.asBytes(&boot));
    std.debug.print("  AFS partition created\n", .{});
}

fn countFiles(dir_path: []const u8) !usize {
    var dir = try fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();
    var count: usize = 0;
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        count += 1;
        if (entry.kind == .directory) {
            const subdir_path = try fs.path.join(std.heap.page_allocator, &[_][]const u8{ dir_path, entry.name });
            defer std.heap.page_allocator.free(subdir_path);
            count += try countFiles(subdir_path);
        }
    }
    return count;
}

fn initAllocationTable(file: fs.File, partition_start: u32, table_size: u32) !void {
    const table_bytes = @as(usize, table_size) * 512;
    var table = try std.heap.page_allocator.alloc(u8, table_bytes);
    defer std.heap.page_allocator.free(table);
    @memset(table, 0);
    mem.writeInt(u32, table[0..4], 0xFFFFFFFF, .little);
    mem.writeInt(u32, table[4..8], 0xFFFFFFFF, .little);
    mem.writeInt(u32, table[8..12], 0xFFFFFFFF, .little);
    try file.seekTo(@as(u64, partition_start + 1) * 512);
    try file.writeAll(table);
}

fn writeAllocationTable(file: fs.File, partition_start: u32, table_size: u32, cluster_alloc: *ClusterAllocator) !void {
    const table_bytes = @as(usize, table_size) * 512;
    var table = try std.heap.page_allocator.alloc(u8, table_bytes);
    defer std.heap.page_allocator.free(table);
    @memset(table, 0);
    mem.writeInt(u32, table[0..4], 0xFFFFFFFF, .little);
    mem.writeInt(u32, table[4..8], 0xFFFFFFFF, .little);
    mem.writeInt(u32, table[8..12], 0xFFFFFFFF, .little);
    for (cluster_alloc.allocations.items) |chain| {
        for (chain.clusters, 0..) |cluster, i| {
            const offset = @as(usize, cluster) * 4;
            const next = if (i == chain.clusters.len - 1) 0xFFFFFFFF else chain.clusters[i + 1];
            mem.writeInt(u32, table[offset..][0..4], next, .little);
        }
    }
    try file.seekTo(@as(u64, partition_start + 1) * 512);
    try file.writeAll(table);
}

fn copyDirectoryAFS(allocator: mem.Allocator, file: fs.File, dir_path: []const u8, partition_start: u32, data_area_start: u32, cluster_alloc: *ClusterAllocator, dir_cluster: u32) !void {
    var dir = try fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();
    var entries: std.ArrayListUnmanaged(AFSDirEntry) = .{};
    defer entries.deinit(allocator);

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const name = entry.name;
        global_file_count += 1;
        printProgress(global_file_count, global_total_files, name);

        var afs_entry = std.mem.zeroes(AFSDirEntry);
        afs_entry.entry_type = if (entry.kind == .directory) ENTRY_TYPE_DIR else ENTRY_TYPE_FILE;
        afs_entry.name_len = @intCast(name.len);
        @memcpy(afs_entry.name[0..name.len], name);

        // Set owner to "akiba"
        const owner = "akiba";
        afs_entry.owner_name_len = @intCast(owner.len);
        @memcpy(afs_entry.owner_name[0..owner.len], owner);

        // Set permissions based on directory
        // system/ - WR, EFI/ - WR, boot/ - WR, binaries/ - WA
        const is_system = std.mem.indexOf(u8, dir_path, "/system") != null or std.mem.eql(u8, name, "system");
        const is_efi = std.mem.indexOf(u8, dir_path, "/EFI") != null or std.mem.eql(u8, name, "EFI");
        const is_boot = std.mem.indexOf(u8, dir_path, "/boot") != null or std.mem.eql(u8, name, "boot");
        const is_binaries = std.mem.indexOf(u8, dir_path, "/binaries") != null or std.mem.eql(u8, name, "binaries");

        if (is_binaries) {
            afs_entry.permission_type = PERM_WORLD;
        } else if (is_system or is_efi or is_boot) {
            afs_entry.permission_type = PERM_READ_ONLY;
        } else {
            afs_entry.permission_type = PERM_OWNER;
        }
        afs_entry.reserved = 0;

        const current_time = std.time.timestamp();
        afs_entry.created_time = @intCast(current_time);
        afs_entry.modified_time = @intCast(current_time);

        if (entry.kind == .directory) {
            const new_cluster = try cluster_alloc.allocate(10);
            afs_entry.first_cluster = new_cluster;
            afs_entry.file_size = 0;
            const subdir_path = try fs.path.join(allocator, &[_][]const u8{ dir_path, name });
            defer allocator.free(subdir_path);
            try copyDirectoryAFS(allocator, file, subdir_path, partition_start, data_area_start, cluster_alloc, new_cluster);
        } else {
            const file_path = try fs.path.join(allocator, &[_][]const u8{ dir_path, name });
            defer allocator.free(file_path);
            const source_file = try fs.cwd().openFile(file_path, .{});
            defer source_file.close();
            const file_size = try source_file.getEndPos();
            afs_entry.file_size = file_size;

            if (file_size > 0) {
                const clusters_needed = (file_size + 511) / 512;
                const file_cluster = try cluster_alloc.allocate(@intCast(clusters_needed));
                afs_entry.first_cluster = file_cluster;
                var cluster_idx: u32 = 0;
                while (cluster_idx < clusters_needed) : (cluster_idx += 1) {
                    var buffer: [512]u8 = undefined;
                    const bytes_read = try source_file.readAll(&buffer);
                    const cluster_lba = partition_start + data_area_start + ((file_cluster + cluster_idx - 2));
                    try file.seekTo(@as(u64, cluster_lba) * 512);
                    try file.writeAll(buffer[0..bytes_read]);
                }
            }
        }
        try entries.append(allocator, afs_entry);
    }

    const cluster_lba_base = partition_start + data_area_start + (dir_cluster - 2);

    for (entries.items, 0..) |entry, i| {
        const cluster_lba = cluster_lba_base + @as(u32, @intCast(i));
        try file.seekTo(@as(u64, cluster_lba) * 512);
        try file.writeAll(mem.asBytes(&entry));

        var padding: [224]u8 = [_]u8{0} ** 224;
        try file.writeAll(&padding);
    }

    const end_cluster_lba = cluster_lba_base + @as(u32, @intCast(entries.items.len));
    try file.seekTo(@as(u64, end_cluster_lba) * 512);
    var end_entry = std.mem.zeroes(AFSDirEntry);
    end_entry.entry_type = ENTRY_TYPE_END;
    try file.writeAll(mem.asBytes(&end_entry));

    var padding: [224]u8 = [_]u8{0} ** 224;
    try file.writeAll(&padding);

    const clusters_used = entries.items.len + 1;
    if (clusters_used < 10) {
        for (clusters_used..10) |i| {
            const pad_cluster_lba = cluster_lba_base + @as(u32, @intCast(i));
            try file.seekTo(@as(u64, pad_cluster_lba) * 512);
            var zero_cluster: [512]u8 = [_]u8{0} ** 512;
            try file.writeAll(&zero_cluster);
        }
    }
}
