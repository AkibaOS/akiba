//! mkafsdisk - Creates bootable Akiba disk image
//!
//! Creates a GPT disk with:
//! - Partition 1: ESP (FAT32) with /EFI/BOOT/BOOTX64.EFI
//! - Partition 2: AFS with /system/akiba/mirai.kernel

const std = @import("std");
const afs = @import("afs/afs.zig");

const SECTOR_SIZE: u32 = 512;
const ESP_SIZE_SECTORS: u32 = 65536; // 32MB for ESP

// ESP partition type GUID: C12A7328-F81F-11D2-BA4B-00A0C93EC93B
const ESP_TYPE_GUID = [16]u8{
    0x28, 0x73, 0x2A, 0xC1,
    0x1F, 0xF8, 0xD2, 0x11,
    0xBA, 0x4B, 0x00, 0xA0,
    0xC9, 0x3E, 0xC9, 0x3B,
};

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = general_purpose_allocator.deinit();
    const allocator = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 4) {
        std.debug.print("Usage: {s} <source_location> <output_image> <size_mb>\n", .{args[0]});
        return error.InvalidArgs;
    }

    const source_location = args[1];
    const output_image_path = args[2];
    const size_megabytes = try std.fmt.parseInt(u32, args[3], 10);

    std.debug.print("Creating disk image: {s}\n", .{output_image_path});
    std.debug.print("  Source: {s}\n", .{source_location});
    std.debug.print("  Size: {d} MB\n", .{size_megabytes});

    try create_disk_image(allocator, source_location, output_image_path, size_megabytes);

    std.debug.print("✓ Disk image created successfully\n", .{});
}

fn create_disk_image(
    allocator: std.mem.Allocator,
    source_location: []const u8,
    output_path: []const u8,
    size_megabytes: u32,
) !void {
    const total_bytes: u64 = @as(u64, size_megabytes) * 1024 * 1024;
    const total_sectors: u32 = @intCast(total_bytes / SECTOR_SIZE);

    // Partition layout:
    // Sector 0: Protective MBR
    // Sector 1: GPT Header
    // Sectors 2-33: GPT Partition Entries
    // Sectors 2048-67583: ESP (FAT32)
    // Sectors 67584+: AFS
    // Last 33 sectors: Backup GPT

    const esp_start_sector: u32 = 2048;
    const esp_end_sector: u32 = esp_start_sector + ESP_SIZE_SECTORS - 1;
    const afs_start_sector: u32 = esp_end_sector + 1;
    const afs_end_sector: u32 = total_sectors - 34;

    std.debug.print("  ESP: sectors {d}-{d}\n", .{ esp_start_sector, esp_end_sector });
    std.debug.print("  AFS: sectors {d}-{d}\n", .{ afs_start_sector, afs_end_sector });

    const file = try std.fs.cwd().createFile(output_path, .{ .read = true });
    defer file.close();

    try file.setEndPos(total_bytes);

    try write_protective_mbr(file, total_sectors);
    try write_gpt(file, esp_start_sector, esp_end_sector, afs_start_sector, afs_end_sector, total_sectors);
    try create_esp(allocator, file, source_location, esp_start_sector, ESP_SIZE_SECTORS);
    try create_afs(allocator, file, source_location, afs_start_sector, afs_end_sector - afs_start_sector + 1);
}

fn write_protective_mbr(file: std.fs.File, total_sectors: u32) !void {
    var mbr: [512]u8 = [_]u8{0} ** 512;

    // Protective MBR partition entry at offset 0x1BE
    mbr[0x1BE + 4] = 0xEE; // GPT protective type
    std.mem.writeInt(u32, mbr[0x1BE + 8 ..][0..4], 1, .little);
    std.mem.writeInt(u32, mbr[0x1BE + 12 ..][0..4], total_sectors - 1, .little);

    // Boot signature
    mbr[510] = 0x55;
    mbr[511] = 0xAA;

    try file.seekTo(0);
    try file.writeAll(&mbr);
}

fn calculate_crc32(data: []const u8) u32 {
    var crc: u32 = 0xFFFFFFFF;
    for (data) |byte| {
        var temp = (crc ^ byte) & 0xFF;
        var iteration: u8 = 0;
        while (iteration < 8) : (iteration += 1) {
            if (temp & 1 != 0) {
                temp = (temp >> 1) ^ 0xEDB88320;
            } else {
                temp >>= 1;
            }
        }
        crc = (crc >> 8) ^ temp;
    }
    return ~crc;
}

fn write_gpt(
    file: std.fs.File,
    esp_start: u32,
    esp_end: u32,
    afs_start: u32,
    afs_end: u32,
    total_sectors: u32,
) !void {
    // Partition entries (128 entries * 128 bytes = 16KB)
    var partition_entries: [16384]u8 = [_]u8{0} ** 16384;

    // ESP partition entry
    @memcpy(partition_entries[0..16], &ESP_TYPE_GUID);
    // Unique partition GUID
    const esp_unique_guid = [16]u8{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10 };
    @memcpy(partition_entries[16..32], &esp_unique_guid);
    std.mem.writeInt(u64, partition_entries[32..40], esp_start, .little);
    std.mem.writeInt(u64, partition_entries[40..48], esp_end, .little);
    // Name: "EFI System"
    const esp_name = "EFI System";
    for (esp_name, 0..) |char, index| {
        partition_entries[56 + index * 2] = char;
    }

    // AFS partition entry
    @memcpy(partition_entries[128..144], &afs.constants.partition_type_guid);
    // Unique partition GUID
    const afs_unique_guid = [16]u8{ 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20 };
    @memcpy(partition_entries[144..160], &afs_unique_guid);
    std.mem.writeInt(u64, partition_entries[160..168], afs_start, .little);
    std.mem.writeInt(u64, partition_entries[168..176], afs_end, .little);
    // Name: "Akiba System"
    const afs_name = "Akiba System";
    for (afs_name, 0..) |char, index| {
        partition_entries[184 + index * 2] = char;
    }

    const entries_crc = calculate_crc32(&partition_entries);

    // GPT Header
    var gpt_header: [512]u8 = [_]u8{0} ** 512;
    @memcpy(gpt_header[0..8], "EFI PART");
    std.mem.writeInt(u32, gpt_header[8..12], 0x00010000, .little); // Revision
    std.mem.writeInt(u32, gpt_header[12..16], 92, .little); // Header size
    // CRC at offset 16 - filled in later
    std.mem.writeInt(u64, gpt_header[24..32], 1, .little); // Current LBA
    std.mem.writeInt(u64, gpt_header[32..40], @as(u64, total_sectors) - 1, .little); // Backup LBA
    std.mem.writeInt(u64, gpt_header[40..48], 34, .little); // First usable LBA
    std.mem.writeInt(u64, gpt_header[48..56], @as(u64, total_sectors) - 34, .little); // Last usable LBA
    // Disk GUID
    const disk_guid = [16]u8{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99 };
    @memcpy(gpt_header[56..72], &disk_guid);
    std.mem.writeInt(u64, gpt_header[72..80], 2, .little); // Partition entries LBA
    std.mem.writeInt(u32, gpt_header[80..84], 128, .little); // Number of entries
    std.mem.writeInt(u32, gpt_header[84..88], 128, .little); // Entry size
    std.mem.writeInt(u32, gpt_header[88..92], entries_crc, .little); // Entries CRC

    const header_crc = calculate_crc32(gpt_header[0..92]);
    std.mem.writeInt(u32, gpt_header[16..20], header_crc, .little);

    // Write primary GPT
    try file.seekTo(SECTOR_SIZE);
    try file.writeAll(&gpt_header);
    try file.seekTo(2 * SECTOR_SIZE);
    try file.writeAll(&partition_entries);

    // Write backup GPT (entries before header at end of disk)
    const backup_entries_lba = total_sectors - 33;
    try file.seekTo(@as(u64, backup_entries_lba) * SECTOR_SIZE);
    try file.writeAll(&partition_entries);

    // Backup GPT header
    var backup_header = gpt_header;
    std.mem.writeInt(u64, backup_header[24..32], @as(u64, total_sectors) - 1, .little);
    std.mem.writeInt(u64, backup_header[32..40], 1, .little);
    std.mem.writeInt(u64, backup_header[72..80], backup_entries_lba, .little);
    std.mem.writeInt(u32, backup_header[16..20], 0, .little);
    const backup_crc = calculate_crc32(backup_header[0..92]);
    std.mem.writeInt(u32, backup_header[16..20], backup_crc, .little);

    try file.seekTo(@as(u64, total_sectors - 1) * SECTOR_SIZE);
    try file.writeAll(&backup_header);
}

fn create_esp(
    allocator: std.mem.Allocator,
    file: std.fs.File,
    source_location: []const u8,
    esp_start_sector: u32,
    esp_sector_count: u32,
) !void {
    std.debug.print("  Creating FAT32 ESP...\n", .{});

    const esp_start_byte: u64 = @as(u64, esp_start_sector) * SECTOR_SIZE;

    const sectors_per_cluster: u32 = 1;
    const reserved_sectors: u32 = 32;
    const fat_count: u32 = 2;

    const available_sectors = esp_sector_count - reserved_sectors;
    const fat_size_sectors = (4 * available_sectors + SECTOR_SIZE * sectors_per_cluster - 1) /
        (SECTOR_SIZE * sectors_per_cluster + 4 * fat_count);
    const data_sectors = available_sectors - (fat_size_sectors * fat_count);
    const total_clusters = data_sectors / sectors_per_cluster;

    // FAT32 Boot Sector
    var boot_sector: [512]u8 = [_]u8{0} ** 512;
    boot_sector[0] = 0xEB;
    boot_sector[1] = 0x58;
    boot_sector[2] = 0x90;
    @memcpy(boot_sector[3..11], "MSWIN4.1");
    std.mem.writeInt(u16, boot_sector[11..13], 512, .little);
    boot_sector[13] = @intCast(sectors_per_cluster);
    std.mem.writeInt(u16, boot_sector[14..16], @intCast(reserved_sectors), .little);
    boot_sector[16] = @intCast(fat_count);
    std.mem.writeInt(u16, boot_sector[17..19], 0, .little);
    std.mem.writeInt(u16, boot_sector[19..21], 0, .little);
    boot_sector[21] = 0xF8;
    std.mem.writeInt(u16, boot_sector[22..24], 0, .little);
    std.mem.writeInt(u16, boot_sector[24..26], 63, .little);
    std.mem.writeInt(u16, boot_sector[26..28], 255, .little);
    std.mem.writeInt(u32, boot_sector[28..32], esp_start_sector, .little);
    std.mem.writeInt(u32, boot_sector[32..36], esp_sector_count, .little);
    std.mem.writeInt(u32, boot_sector[36..40], fat_size_sectors, .little);
    std.mem.writeInt(u16, boot_sector[40..42], 0, .little);
    std.mem.writeInt(u16, boot_sector[42..44], 0, .little);
    std.mem.writeInt(u32, boot_sector[44..48], 2, .little);
    std.mem.writeInt(u16, boot_sector[48..50], 1, .little);
    std.mem.writeInt(u16, boot_sector[50..52], 6, .little);
    boot_sector[64] = 0x80;
    boot_sector[66] = 0x29;
    std.mem.writeInt(u32, boot_sector[67..71], 0x12345678, .little);
    @memcpy(boot_sector[71..82], "AKIBAOS    ");
    @memcpy(boot_sector[82..90], "FAT32   ");
    boot_sector[510] = 0x55;
    boot_sector[511] = 0xAA;

    try file.seekTo(esp_start_byte);
    try file.writeAll(&boot_sector);

    // FSInfo
    var fsinfo: [512]u8 = [_]u8{0} ** 512;
    std.mem.writeInt(u32, fsinfo[0..4], 0x41615252, .little);
    std.mem.writeInt(u32, fsinfo[484..488], 0x61417272, .little);
    std.mem.writeInt(u32, fsinfo[488..492], 0xFFFFFFFF, .little);
    std.mem.writeInt(u32, fsinfo[492..496], 0xFFFFFFFF, .little);
    std.mem.writeInt(u32, fsinfo[508..512], 0xAA550000, .little);

    try file.seekTo(esp_start_byte + SECTOR_SIZE);
    try file.writeAll(&fsinfo);

    // Backup boot sector
    try file.seekTo(esp_start_byte + 6 * SECTOR_SIZE);
    try file.writeAll(&boot_sector);

    // FAT table
    const fat_bytes = fat_size_sectors * SECTOR_SIZE;
    var fat_table = try allocator.alloc(u8, fat_bytes);
    defer allocator.free(fat_table);
    @memset(fat_table, 0);

    std.mem.writeInt(u32, fat_table[0..4], 0x0FFFFFF8, .little);
    std.mem.writeInt(u32, fat_table[4..8], 0x0FFFFFFF, .little);
    std.mem.writeInt(u32, fat_table[8..12], 0x0FFFFFFF, .little);

    const fat1_offset = esp_start_byte + reserved_sectors * SECTOR_SIZE;
    const fat2_offset = fat1_offset + fat_bytes;
    const data_start = fat2_offset + fat_bytes;

    // Copy EFI/BOOT/BOOTX64.EFI from source
    var current_cluster: u32 = 3;

    // Origin stack (root)
    var origin_stack: [512]u8 = [_]u8{0} ** 512;

    // EFI stack entry in origin
    @memcpy(origin_stack[0..11], "EFI        ");
    origin_stack[11] = 0x10;
    std.mem.writeInt(u16, origin_stack[26..28], @intCast(current_cluster), .little);
    const efi_cluster = current_cluster;
    current_cluster += 1;

    // Write origin stack at cluster 2
    try file.seekTo(data_start);
    try file.writeAll(&origin_stack);

    // EFI stack
    var efi_stack: [512]u8 = [_]u8{0} ** 512;
    @memcpy(efi_stack[0..11], ".          ");
    efi_stack[11] = 0x10;
    std.mem.writeInt(u16, efi_stack[26..28], @intCast(efi_cluster), .little);
    @memcpy(efi_stack[32..43], "..         ");
    efi_stack[43] = 0x10;
    @memcpy(efi_stack[64..75], "BOOT       ");
    efi_stack[75] = 0x10;
    std.mem.writeInt(u16, efi_stack[90..92], @intCast(current_cluster), .little);
    const boot_cluster = current_cluster;
    current_cluster += 1;

    try file.seekTo(data_start + (efi_cluster - 2) * SECTOR_SIZE);
    try file.writeAll(&efi_stack);
    std.mem.writeInt(u32, fat_table[efi_cluster * 4 ..][0..4], 0x0FFFFFFF, .little);

    // BOOT stack
    var boot_stack: [512]u8 = [_]u8{0} ** 512;
    @memcpy(boot_stack[0..11], ".          ");
    boot_stack[11] = 0x10;
    std.mem.writeInt(u16, boot_stack[26..28], @intCast(boot_cluster), .little);
    @memcpy(boot_stack[32..43], "..         ");
    boot_stack[43] = 0x10;
    std.mem.writeInt(u16, boot_stack[58..60], @intCast(efi_cluster), .little);

    // Try to find and copy BOOTX64.EFI
    const bootloader_location = try std.fs.path.join(allocator, &.{ source_location, "EFI", "BOOT", "BOOTX64.EFI" });
    defer allocator.free(bootloader_location);

    const bootloader_file = std.fs.cwd().openFile(bootloader_location, .{}) catch |err| {
        std.debug.print("    Warning: Cannot open bootloader: {}\n", .{err});
        try file.seekTo(data_start + (boot_cluster - 2) * SECTOR_SIZE);
        try file.writeAll(&boot_stack);
        std.mem.writeInt(u32, fat_table[boot_cluster * 4 ..][0..4], 0x0FFFFFFF, .little);
        try file.seekTo(fat1_offset);
        try file.writeAll(fat_table);
        try file.seekTo(fat2_offset);
        try file.writeAll(fat_table);
        return;
    };
    defer bootloader_file.close();

    const bootloader_size = try bootloader_file.getEndPos();
    const bootloader_clusters = @as(u32, @intCast((bootloader_size + SECTOR_SIZE - 1) / SECTOR_SIZE));

    std.debug.print("    Adding BOOTX64.EFI ({d} bytes, {d} clusters)\n", .{ bootloader_size, bootloader_clusters });

    // Add BOOTX64.EFI entry
    @memcpy(boot_stack[64..75], "BOOTX64 EFI");
    boot_stack[75] = 0x20;
    std.mem.writeInt(u16, boot_stack[90..92], @intCast(current_cluster), .little);
    std.mem.writeInt(u32, boot_stack[92..96], @intCast(bootloader_size), .little);
    const bootloader_start_cluster = current_cluster;

    try file.seekTo(data_start + (boot_cluster - 2) * SECTOR_SIZE);
    try file.writeAll(&boot_stack);
    std.mem.writeInt(u32, fat_table[boot_cluster * 4 ..][0..4], 0x0FFFFFFF, .little);

    // Copy bootloader data
    var cluster_index: u32 = 0;
    while (cluster_index < bootloader_clusters) : (cluster_index += 1) {
        var buffer: [512]u8 = [_]u8{0} ** 512;
        _ = try bootloader_file.read(&buffer);

        const cluster_number = bootloader_start_cluster + cluster_index;
        const cluster_offset = data_start + (cluster_number - 2) * SECTOR_SIZE;
        try file.seekTo(cluster_offset);
        try file.writeAll(&buffer);

        const next_cluster: u32 = if (cluster_index == bootloader_clusters - 1) 0x0FFFFFFF else (cluster_number + 1);
        std.mem.writeInt(u32, fat_table[cluster_number * 4 ..][0..4], next_cluster, .little);
    }

    // Write FAT tables
    try file.seekTo(fat1_offset);
    try file.writeAll(fat_table);
    try file.seekTo(fat2_offset);
    try file.writeAll(fat_table);

    _ = total_clusters;
    std.debug.print("    FAT32 ESP created\n", .{});
}

fn create_afs(
    allocator: std.mem.Allocator,
    file: std.fs.File,
    source_location: []const u8,
    afs_start_sector: u32,
    afs_sector_count: u32,
) !void {
    const partition_start_byte: u64 = @as(u64, afs_start_sector) * SECTOR_SIZE;
    const partition_size_bytes: u64 = @as(u64, afs_sector_count) * SECTOR_SIZE;

    var writer = afs.Writer.initialize(
        file,
        partition_start_byte,
        partition_size_bytes,
        allocator,
    );

    try writer.create_filesystem(source_location);
}
