//! Hikari EFI Interface

const std = @import("std");

pub const akiba: std.builtin.CallingConvention = .{ .x86_64_win = .{} };

pub const constants = @import("constants/constants.zig");
pub const types = @import("types/types.zig");
pub const services = @import("services/services.zig");
pub const protocols = @import("protocols/protocols.zig");
