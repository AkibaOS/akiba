//! Disk Image Integration Names And Contents

pub const CURRENT_DIRECTORY = ".";
pub const SOURCE_DIRECTORY = "source";
pub const IMAGE_NAME = "disk.img";
pub const DISK_REPORT_PATH = "out/disk.img";
pub const DISK_REPORT = "[5/5] Packed units: disk.img\n" ++
    "Creating disk image: out/disk.img\n" ++
    "  Source: source\n" ++
    "  Size: 64 MB\n" ++
    "  ESP: sectors 2048-71679\n" ++
    "  AFS: sectors 71680-131038\n" ++
    "  Creating FAT32 ESP...\n" ++
    "    Adding BOOTX64.EFI (769 bytes, 2 clusters)\n" ++
    "    FAT32 ESP created (68528 clusters)\n" ++
    "  Creating AFS filesystem...\n" ++
    "    Total cells: 7419\n" ++
    "    Cell size: 4096\n" ++
    "    Units: 5, Stacks: 4\n" ++
    "    Free cells: 7409\n" ++
    "Disk image created successfully\n";
pub const BOOT_DIRECTORY = "source/EFI/BOOT";
pub const DOCS_DIRECTORY = "source/docs";
pub const BOOTLOADER_PATH = "source/EFI/BOOT/BOOTX64.EFI";
pub const TINY_PATH = "source/tiny.bin";
pub const CROSS_PATH = "source/cross.bin";
pub const EMPTY_PATH = "source/empty.bin";
pub const NOTE_PATH = "source/docs/note.txt";
pub const HIDDEN_PATH = "source/.hidden";
pub const TINY_CONTENT = "tiny\x00payload\xFF";
pub const NOTE_CONTENT = "nested image payload\n";
pub const EMPTY_CONTENT = "";
pub const HIDDEN_CONTENT = "not an installed unit";
pub const GPT_SIGNATURE = "EFI PART";
pub const ESP_PARTITION_NAME = "EFI System";
pub const AFS_PARTITION_NAME = "Akiba System";
pub const EFI_NAME = "EFI";
pub const BOOT_NAME = "BOOT";
pub const BOOTLOADER_NAME = "BOOTX64.EFI";
pub const CURRENT_NAME = ".";
pub const PARENT_NAME = "..";
pub const EMPTY_IDENTITY = [_]u16{};
pub const EFI_IDENTITY = [_]u16{ 'E', 'F', 'I' };
pub const BOOT_IDENTITY = [_]u16{ 'B', 'O', 'O', 'T' };
pub const DOCS_IDENTITY = [_]u16{ 'd', 'o', 'c', 's' };
pub const BOOTLOADER_IDENTITY = [_]u16{ 'B', 'O', 'O', 'T', 'X', '6', '4', '.', 'E', 'F', 'I' };
pub const TINY_IDENTITY = [_]u16{ 't', 'i', 'n', 'y', '.', 'b', 'i', 'n' };
pub const CROSS_IDENTITY = [_]u16{ 'c', 'r', 'o', 's', 's', '.', 'b', 'i', 'n' };
pub const EMPTY_UNIT_IDENTITY = [_]u16{ 'e', 'm', 'p', 't', 'y', '.', 'b', 'i', 'n' };
pub const NOTE_IDENTITY = [_]u16{ 'n', 'o', 't', 'e', '.', 't', 'x', 't' };
pub const HIDDEN_IDENTITY = [_]u16{ '.', 'h', 'i', 'd', 'd', 'e', 'n' };
