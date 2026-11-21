//! Reuse Demand Mapped Scratch Pages Across Weaver Requests

const std = @import("std");

const invoke = @import("personaasm").invoke;
const layout = @import("shared").launch.constants.service.memory;
const sizes = @import("common").constants.memory.sizes;

const Operation = @import("shared").pulse.types.boot.control.Operation;
const State = @import("weaver").memory.types.arena.state.State;
const Status = @import("shared").persona.types.invocation.Status;

var state: State = .{};

pub fn reset() std.mem.Allocator {
    state.Used = 0;
    return .{ .ptr = &state, .vtable = &.{
        .alloc = allocate,
        .resize = std.mem.Allocator.noResize,
        .remap = std.mem.Allocator.noRemap,
        .free = std.mem.Allocator.noFree,
    } };
}

fn allocate(context: *anyopaque, length: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8 {
    const arena: *State = @ptrCast(@alignCast(context));
    const absolute = std.math.add(usize, layout.BASE, arena.Used) catch return null;
    const rounded = std.math.add(usize, absolute, alignment.toByteUnits() - 1) catch return null;
    const address = rounded & ~(alignment.toByteUnits() - 1);
    const end = std.math.add(usize, address - layout.BASE, length) catch return null;
    while (arena.Mapped < end) {
        const result = invoke.call(.BootstrapWeaver, @intFromEnum(Operation.Grow), 0, 0, 0);
        if (result.Status != @intFromEnum(Status.Success) or result.Value != layout.BASE + arena.Mapped) return null;
        arena.Mapped += sizes.PAGE_SIZE;
    }
    arena.Used = end;
    return @ptrFromInt(address);
}
