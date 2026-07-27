//! mkafsdisk Format Names And Labels

pub const ESP_PARTITION_NAME = "EFI System";
pub const AFS_PARTITION_NAME = "Akiba System";

pub const GPT_SIGNATURE = "EFI PART";
pub const FAT_VOLUME_LABEL: [11]u8 = .{ 'A', 'K', 'I', 'B', 'A', ' ', 'E', 'F', 'I', ' ', ' ' };

pub const STACK_EFI = "EFI";
pub const STACK_BOOT = "BOOT";
pub const UNIT_BOOTLOADER = "BOOTX64.EFI";

pub const ENTRY_BOOTLOADER_NAME = "BOOTX64";
pub const ENTRY_BOOTLOADER_EXTENSION = "EFI";
pub const ENTRY_CURRENT = ".";
pub const ENTRY_PARENT = "..";
