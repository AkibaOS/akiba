//! Debug Register Instructions

pub const READ_DR0 = "mov %%dr0, %[value]";
pub const READ_DR1 = "mov %%dr1, %[value]";
pub const READ_DR2 = "mov %%dr2, %[value]";
pub const READ_DR3 = "mov %%dr3, %[value]";
pub const READ_DR6 = "mov %%dr6, %[value]";
pub const READ_DR7 = "mov %%dr7, %[value]";

pub const WRITE_DR0 = "mov %[value], %%dr0";
pub const WRITE_DR1 = "mov %[value], %%dr1";
pub const WRITE_DR2 = "mov %[value], %%dr2";
pub const WRITE_DR3 = "mov %[value], %%dr3";
pub const WRITE_DR6 = "mov %[value], %%dr6";
pub const WRITE_DR7 = "mov %[value], %%dr7";
