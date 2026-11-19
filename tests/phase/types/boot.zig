//! Test Disk Launch Roles

const wire = @import("tests").phase.constants.boot;

pub const Role = enum(u8) { Diagnostic, Firmware, Menu, Ordinary };
pub const Kind = enum { Offer, Acknowledgement };
pub const Selection = struct { Epoch: u64, Role: Role };
pub const Frame = [wire.FRAME_BYTES]u8;
