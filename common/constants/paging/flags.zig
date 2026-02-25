//! Paging Flag Constants

pub const present: u64 = 1 << 0;
pub const writable: u64 = 1 << 1;
pub const user_accessible: u64 = 1 << 2;
pub const write_through: u64 = 1 << 3;
pub const cache_disabled: u64 = 1 << 4;
pub const accessed: u64 = 1 << 5;
pub const dirty: u64 = 1 << 6;
pub const huge_page: u64 = 1 << 7;
pub const global: u64 = 1 << 8;
pub const no_execute: u64 = 1 << 63;

pub const kernel_read_only: u64 = present | global;
pub const kernel_read_write: u64 = present | writable | global;
pub const kernel_execute: u64 = present | global;
pub const kernel_read_write_no_execute: u64 = present | writable | global | no_execute;

pub const user_read_only: u64 = present | user_accessible;
pub const user_read_write: u64 = present | writable | user_accessible;
pub const user_execute: u64 = present | user_accessible;
pub const user_read_write_no_execute: u64 = present | writable | user_accessible | no_execute;

pub const table_flags: u64 = present | writable | user_accessible;
pub const kernel_table_flags: u64 = present | writable;

pub const mmio_flags: u64 = present | writable | cache_disabled | no_execute;
