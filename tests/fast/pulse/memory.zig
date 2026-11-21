//! Verify Persona Scratch Reuse Against Finite Backing

const std = @import("std");

const arena = @import("shared").persona.memory.arena;
const sizes = @import("common").constants.memory.sizes;

const Backing = @import("tests").fast.pulse.types.memory.Backing;
const State = @import("shared").persona.types.memory.arena.State;

var backing: Backing = .{};

pub fn reusesFreedTail() !void {
    backing.Mapped = 0;
    var state: State = .{ .Base = @intFromPtr(&backing.Bytes), .Grow = grow };
    const allocator = arena.reset(&state);
    const first = try allocator.alloc(u8, sizes.PAGE_SIZE);
    @memset(first, 0x5a);
    const second = try allocator.alloc(u8, sizes.PAGE_SIZE);
    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 1));
    allocator.free(second);
    const again = try allocator.alloc(u8, sizes.PAGE_SIZE);
    try std.testing.expectEqual(@intFromPtr(second.ptr), @intFromPtr(again.ptr));
    for (first) |byte| try std.testing.expectEqual(@as(u8, 0x5a), byte);
}

fn grow() ?u64 {
    if (backing.Mapped == backing.Bytes.len) return null;
    const address = @intFromPtr(&backing.Bytes) + backing.Mapped;
    backing.Mapped += sizes.PAGE_SIZE;
    return address;
}
