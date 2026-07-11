//! mkafsdisk Format Names And Labels

pub const esp_partition_name = "EFI System";
pub const afs_partition_name = "Akiba System";

pub const gpt_signature = "EFI PART";
pub const fat_oem_name = "MSWIN4.1";
pub const fat_volume_label = "AKIBAOS    ";
pub const fat_filesystem_type = "FAT32   ";

pub const dir_entry_efi = "EFI        ";
pub const dir_entry_boot = "BOOT       ";
pub const dir_entry_current = ".          ";
pub const dir_entry_parent = "..         ";
pub const dir_entry_bootloader = "BOOTX64 EFI";

pub const stack_efi = "EFI";
pub const stack_boot = "BOOT";
pub const unit_bootloader = "BOOTX64.EFI";
