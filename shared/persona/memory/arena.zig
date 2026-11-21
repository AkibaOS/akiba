//! Reuse Demand Mapped Scratch Pages Across Persona Requests

const std = @import("std");

const sizes = @import("common").constants.memory.sizes;

const State = @import("shared").persona.types.memory.arena.State;

pub fn reset(state: *State) std.mem.Allocator {
    state.Used = 0;
    return .{ .ptr = state, .vtable = &.{
        .alloc = allocate,
        .resize = std.mem.Allocator.noResize,
        .remap = std.mem.Allocator.noRemap,
        .free = free,
    } };
}

fn free(context: *anyopaque, bytes: []u8, _: std.mem.Alignment, _: usize) void {
    const arena: *State = @ptrCast(@alignCast(context));
    const address = @intFromPtr(bytes.ptr);
    const end = std.math.add(usize, address, bytes.len) catch return;
    if (address >= arena.Base and end == arena.Base + arena.Used) arena.Used = address - arena.Base;
}

fn allocate(context: *anyopaque, length: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8 {
    const arena: *State = @ptrCast(@alignCast(context));
    const absolute = std.math.add(usize, arena.Base, arena.Used) catch return null;
    const rounded = std.math.add(usize, absolute, alignment.toByteUnits() - 1) catch return null;
    const address = rounded & ~(alignment.toByteUnits() - 1);
    const end = std.math.add(usize, address - arena.Base, length) catch return null;
    while (arena.Mapped < end) {
        const next = arena.Grow() orelse return null;
        if (next != arena.Base + arena.Mapped) return null;
        arena.Mapped += sizes.PAGE_SIZE;
    }
    arena.Used = end;
    return @ptrFromInt(address);
}
