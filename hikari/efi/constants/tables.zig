//! Hikari EFI Table Signature Constants

pub const system_table_signature: u64 = 0x5453595320494249;
pub const boot_services_signature: u64 = 0x56524553544f4f42;
pub const runtime_services_signature: u64 = 0x56524553544e5552;

pub const system_table_revision_2_100: u32 = (2 << 16) | 100;
pub const system_table_revision_2_90: u32 = (2 << 16) | 90;
pub const system_table_revision_2_80: u32 = (2 << 16) | 80;
pub const system_table_revision_2_70: u32 = (2 << 16) | 70;
pub const system_table_revision_2_60: u32 = (2 << 16) | 60;
pub const system_table_revision_2_50: u32 = (2 << 16) | 50;
pub const system_table_revision_2_40: u32 = (2 << 16) | 40;
pub const system_table_revision_2_31: u32 = (2 << 16) | 31;
pub const system_table_revision_2_30: u32 = (2 << 16) | 30;
pub const system_table_revision_2_20: u32 = (2 << 16) | 20;
pub const system_table_revision_2_10: u32 = (2 << 16) | 10;
pub const system_table_revision_2_00: u32 = (2 << 16) | 0;
pub const system_table_revision_1_10: u32 = (1 << 16) | 10;
pub const system_table_revision_1_02: u32 = (1 << 16) | 2;

pub const specification_major_revision: u32 = 2;
pub const specification_minor_revision: u32 = 100;
