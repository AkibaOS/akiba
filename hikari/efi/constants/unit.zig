//! Hikari EFI Unit Constants

pub const unit_mode_read: u64 = 0x0000000000000001;
pub const unit_mode_write: u64 = 0x0000000000000002;
pub const unit_mode_create: u64 = 0x8000000000000000;

pub const unit_attribute_read_only: u64 = 0x0000000000000001;
pub const unit_attribute_hidden: u64 = 0x0000000000000002;
pub const unit_attribute_system: u64 = 0x0000000000000004;
pub const unit_attribute_reserved: u64 = 0x0000000000000008;
pub const unit_attribute_stack: u64 = 0x0000000000000010;
pub const unit_attribute_archive: u64 = 0x0000000000000020;
pub const unit_attribute_valid: u64 = 0x0000000000000037;

pub const unit_protocol_revision: u64 = 0x00010000;
pub const unit_protocol_revision2: u64 = 0x00020000;
pub const unit_protocol_latest_revision: u64 = unit_protocol_revision2;

pub const simple_unit_system_protocol_revision: u64 = 0x00010000;
