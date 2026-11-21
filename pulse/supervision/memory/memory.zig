//! Initial Pulse Demand Mapped Scratch Memory

const std = @import("std");

const arena = @import("shared").persona.memory.arena;
const invoke = @import("personaasm").invoke;

const Operation = @import("shared").pulse.types.boot.control.Operation;
const State = @import("shared").persona.types.memory.arena.State;
const Status = @import("shared").persona.types.invocation.Status;

var state: State = .{ .Grow = grow };

pub fn allocator() std.mem.Allocator {
    return arena.reset(&state);
}

fn grow() ?u64 {
    const result = invoke.call(.BootstrapWeaver, @intFromEnum(Operation.Grow), 0, 0, 0);
    return if (result.Status == @intFromEnum(Status.Success)) result.Value else null;
}
