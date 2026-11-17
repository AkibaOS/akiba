//! Native Kernel Standard Allocator Adapter

const std = @import("std");

const constants = @import("mirai").memory.constants.allocator.native;
const heap = @import("mirai").memory.heap;
const kalloc = @import("mirai").memory.kalloc;

var context: u8 = 0;

pub fn get() std.mem.Allocator {
    return .{ .ptr = &context, .vtable = &constants.VTABLE };
}

pub fn allocate(pointer: *anyopaque, length: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
    _ = pointer;
    _ = address;
    const bytes = alignment.toByteUnits();
    const result = if (kalloc.supports(length, bytes))
        kalloc.kalloc(length) catch return null
    else
        heap.allocate.allocate(length, bytes) catch return null;
    return @ptrCast(result);
}

pub fn release(pointer: *anyopaque, buffer: []u8, alignment: std.mem.Alignment, address: usize) void {
    _ = pointer;
    _ = alignment;
    _ = address;
    if (buffer.len != 0) kalloc.kfree(@ptrCast(buffer.ptr), buffer.len);
}
