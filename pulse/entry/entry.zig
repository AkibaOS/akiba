//! Standalone Pulse ELF Entry

const std = @import("std");

const assembly = @import("personaasm");
const run = @import("pulse").supervision.inbox;

const Status = @import("shared").persona.types.invocation.Status;

comptime {
    _ = assembly.entry.pulse_entry;
}

export fn pulse_main() callconv(.{ .x86_64_sysv = .{} }) noreturn {
    run.listen();
}

pub const panic = std.debug.FullPanic(fault);

fn fault(_: []const u8, _: ?usize) noreturn {
    run.stop(@intFromEnum(Status.InvalidState));
}
