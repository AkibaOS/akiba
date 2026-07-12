//! mkafsdisk Format Names And Labels

pub const ESP_PARTITION_NAME = "EFI System";
pub const AFS_PARTITION_NAME = "Akiba System";

pub const GPT_SIGNATURE = "EFI PART";
pub const FAT_OEM_NAME = "MSWIN4.1";
pub const FAT_VOLUME_LABEL = "AKIBAOS    ";
pub const FAT_FILESYSTEM_TYPE = "FAT32   ";

pub const DIR_ENTRY_EFI = "EFI        ";
pub const DIR_ENTRY_BOOT = "BOOT       ";
pub const DIR_ENTRY_CURRENT = ".          ";
pub const DIR_ENTRY_PARENT = "..         ";
pub const DIR_ENTRY_BOOTLOADER = "BOOTX64 EFI";

pub const STACK_EFI = "EFI";
pub const STACK_BOOT = "BOOT";
pub const UNIT_BOOTLOADER = "BOOTX64.EFI";
