//! IDT Load Operations

pub const lidt = @import("lidt.zig");

pub const load = lidt.load;
pub const sidt = lidt.sidt;
