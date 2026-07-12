//! Hikari EFI Calling Convention

const std = @import("std");

pub const CALLING_CONVENTION: std.builtin.CallingConvention = .{ .x86_64_win = .{} };
