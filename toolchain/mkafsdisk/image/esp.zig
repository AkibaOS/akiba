//! FAT32 ESP Creation

const std = @import("std");

const fat32 = @import("shared").fat32;

const constants = @import("mkafsdisk").constants;
const strings = @import("mkafsdisk").strings;

const disk = constants.disk;
const esp = constants.esp;
const messages = strings.messages;
const names = strings.names;

const BootSector = fat32.types.boot.BootSector;
const StackEntry = fat32.types.entry.StackEntry;

pub fn createEsp(
    allocator: std.mem.Allocator,
    file: std.fs.File,
    source_location: []const u8,
    esp_start_sector: u32,
    esp_sector_count: u32,
) !void {
    std.debug.print(messages.ESP_CREATING, .{});

    const esp_start_byte: u64 = @as(u64, esp_start_sector) * disk.SECTOR_SIZE;

    const available_sectors = esp_sector_count - esp.RESERVED_SECTORS;
    const fat_size_sectors = (@sizeOf(u32) * available_sectors + disk.SECTOR_SIZE * esp.SECTORS_PER_CLUSTER - 1) /
        (disk.SECTOR_SIZE * esp.SECTORS_PER_CLUSTER + @sizeOf(u32) * esp.FAT_COUNT);
    const data_sectors = available_sectors - (fat_size_sectors * esp.FAT_COUNT);
    const total_clusters = data_sectors / esp.SECTORS_PER_CLUSTER;

    const boot_sector = BootSector{
        .JumpBoot = fat32.constants.defaults.DEFAULT_JUMP_BOOT,
        .OemName = fat32.constants.defaults.DEFAULT_OEM_NAME,
        .BytesPerSector = disk.SECTOR_SIZE,
        .SectorsPerCluster = esp.SECTORS_PER_CLUSTER,
        .ReservedSectors = esp.RESERVED_SECTORS,
        .FatCount = esp.FAT_COUNT,
        .RootEntryCount = 0,
        .TotalSectors16 = 0,
        .MediaType = fat32.constants.defaults.DEFAULT_MEDIA_TYPE,
        .FatSize16 = 0,
        .SectorsPerTrack = fat32.constants.defaults.DEFAULT_SECTORS_PER_TRACK,
        .HeadCount = fat32.constants.defaults.DEFAULT_HEAD_COUNT,
        .HiddenSectors = esp_start_sector,
        .TotalSectors32 = esp_sector_count,
        .FatSize32 = fat_size_sectors,
        .ExtFlags = 0,
        .FsVersion = 0,
        .RootCluster = esp.FIRST_DATA_CLUSTER,
        .FsInfoSector = @intCast(esp.FSINFO_SECTOR),
        .BackupBootSector = @intCast(esp.BACKUP_BOOT_SECTOR),
        .Reserved = [_]u8{0} ** 12,
        .DriveNumber = fat32.constants.defaults.DEFAULT_DRIVE_NUMBER,
        .Reserved1 = 0,
        .BootSignature = fat32.constants.defaults.DEFAULT_EXTENDED_BOOT_SIGNATURE,
        .VolumeId = esp.VOLUME_ID,
        .VolumeLabel = names.FAT_VOLUME_LABEL,
        .FsType = fat32.constants.magic.FS_TYPE_FAT32,
        .BootCode = [_]u8{0} ** 420,
        .Signature = fat32.constants.magic.BOOT_SIGNATURE,
    };

    var boot_sector_bytes: [disk.SECTOR_SIZE]u8 = [_]u8{0} ** disk.SECTOR_SIZE;
    @memcpy(boot_sector_bytes[0..@sizeOf(BootSector)], std.mem.asBytes(&boot_sector));

    try file.seekTo(esp_start_byte);
    try file.writeAll(&boot_sector_bytes);

    const fsinfo = fat32.write.boot.createFsInfo(fat32.constants.magic.FSINFO_UNKNOWN, fat32.constants.magic.FSINFO_UNKNOWN);
    var fsinfo_bytes: [disk.SECTOR_SIZE]u8 = [_]u8{0} ** disk.SECTOR_SIZE;
    @memcpy(fsinfo_bytes[0..@sizeOf(fat32.types.boot.FsInfo)], std.mem.asBytes(&fsinfo));

    try file.seekTo(esp_start_byte + esp.FSINFO_SECTOR * disk.SECTOR_SIZE);
    try file.writeAll(&fsinfo_bytes);

    try file.seekTo(esp_start_byte + esp.BACKUP_BOOT_SECTOR * disk.SECTOR_SIZE);
    try file.writeAll(&boot_sector_bytes);

    const fat_bytes = fat_size_sectors * disk.SECTOR_SIZE;
    const fat_table = try allocator.alloc(u8, fat_bytes);
    defer allocator.free(fat_table);
    fat32.write.boot.initFatTable(fat_table);

    const fat1_offset = esp_start_byte + esp.RESERVED_SECTORS * disk.SECTOR_SIZE;
    const fat2_offset = fat1_offset + fat_bytes;
    const data_start = fat2_offset + fat_bytes;

    var current_cluster: u32 = esp.FIRST_FREE_CLUSTER;

    var origin_stack: [disk.SECTOR_SIZE]u8 = [_]u8{0} ** disk.SECTOR_SIZE;

    const efi_cluster = current_cluster;
    current_cluster += 1;
    writeEntry(&origin_stack, 0, fat32.write.entry.createStackEntry(names.STACK_EFI, efi_cluster));

    try file.seekTo(data_start);
    try file.writeAll(&origin_stack);

    var efi_stack: [disk.SECTOR_SIZE]u8 = [_]u8{0} ** disk.SECTOR_SIZE;
    writeEntry(&efi_stack, 0, fat32.write.entry.createDotEntry(efi_cluster));
    writeEntry(&efi_stack, 1, fat32.write.entry.createDotDotEntry(0));
    const boot_cluster = current_cluster;
    current_cluster += 1;
    writeEntry(&efi_stack, 2, fat32.write.entry.createStackEntry(names.STACK_BOOT, boot_cluster));

    try file.seekTo(data_start + (efi_cluster - esp.FIRST_DATA_CLUSTER) * disk.SECTOR_SIZE);
    try file.writeAll(&efi_stack);
    fat32.write.boot.allocateCluster(fat_table, efi_cluster);

    var boot_stack: [disk.SECTOR_SIZE]u8 = [_]u8{0} ** disk.SECTOR_SIZE;
    writeEntry(&boot_stack, 0, fat32.write.entry.createDotEntry(boot_cluster));
    writeEntry(&boot_stack, 1, fat32.write.entry.createDotDotEntry(efi_cluster));

    const bootloader_location = try std.fs.path.join(allocator, &.{ source_location, names.STACK_EFI, names.STACK_BOOT, names.UNIT_BOOTLOADER });
    defer allocator.free(bootloader_location);

    const bootloader_file = std.fs.cwd().openFile(bootloader_location, .{}) catch |err| {
        std.debug.print(messages.BOOTLOADER_MISSING, .{err});
        try file.seekTo(data_start + (boot_cluster - esp.FIRST_DATA_CLUSTER) * disk.SECTOR_SIZE);
        try file.writeAll(&boot_stack);
        fat32.write.boot.allocateCluster(fat_table, boot_cluster);
        try file.seekTo(fat1_offset);
        try file.writeAll(fat_table);
        try file.seekTo(fat2_offset);
        try file.writeAll(fat_table);
        return;
    };
    defer bootloader_file.close();

    const bootloader_size = try bootloader_file.getEndPos();
    const bootloader_clusters = @as(u32, @intCast((bootloader_size + disk.SECTOR_SIZE - 1) / disk.SECTOR_SIZE));

    std.debug.print(messages.BOOTLOADER_ADDING, .{ bootloader_size, bootloader_clusters });

    const bootloader_start_cluster = current_cluster;
    writeEntry(&boot_stack, 2, fat32.write.entry.createUnitEntry(
        names.ENTRY_BOOTLOADER_NAME,
        names.ENTRY_BOOTLOADER_EXTENSION,
        bootloader_start_cluster,
        @intCast(bootloader_size),
    ));

    try file.seekTo(data_start + (boot_cluster - esp.FIRST_DATA_CLUSTER) * disk.SECTOR_SIZE);
    try file.writeAll(&boot_stack);
    fat32.write.boot.allocateCluster(fat_table, boot_cluster);

    var cluster_index: u32 = 0;
    while (cluster_index < bootloader_clusters) : (cluster_index += 1) {
        var buffer: [disk.SECTOR_SIZE]u8 = [_]u8{0} ** disk.SECTOR_SIZE;
        _ = try bootloader_file.read(&buffer);

        const cluster_number = bootloader_start_cluster + cluster_index;
        const cluster_offset = data_start + (cluster_number - esp.FIRST_DATA_CLUSTER) * disk.SECTOR_SIZE;
        try file.seekTo(cluster_offset);
        try file.writeAll(&buffer);

        if (cluster_index == bootloader_clusters - 1) {
            fat32.write.boot.allocateCluster(fat_table, cluster_number);
        } else {
            fat32.write.boot.linkClusters(fat_table, cluster_number, cluster_number + 1);
        }
    }

    try file.seekTo(fat1_offset);
    try file.writeAll(fat_table);
    try file.seekTo(fat2_offset);
    try file.writeAll(fat_table);

    if (total_clusters < disk.FAT32_MINIMUM_CLUSTERS) {
        std.debug.print(messages.ESP_TOO_SMALL, .{ total_clusters, disk.FAT32_MINIMUM_CLUSTERS });
        return error.EspTooSmall;
    }

    std.debug.print(messages.ESP_CREATED, .{total_clusters});
}

fn writeEntry(sector: []u8, slot: usize, entry: StackEntry) void {
    const offset = slot * esp.DIRECTORY_ENTRY_SIZE;
    @memcpy(sector[offset..][0..esp.DIRECTORY_ENTRY_SIZE], std.mem.asBytes(&entry));
}
