//! Kernel Standard Allocator Callback Table

const std = @import("std");

const native = @import("mirai").memory.allocator.native;

pub const VTABLE: std.mem.Allocator.VTable = .{
    .alloc = native.allocate,
    .resize = std.mem.Allocator.noResize,
    .remap = std.mem.Allocator.noRemap,
    .free = native.release,
};
