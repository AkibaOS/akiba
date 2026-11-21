//! Standalone Resident Weaver ELF Entry

const std = @import("std");

const assembly = @import("personaasm");
const inbox = @import("weaver").supervision.inbox;

const Status = @import("shared").persona.types.invocation.Status;

comptime {
    _ = assembly.entry.weaver.weaver_entry;
}

export fn weaver_main(pulse: u64) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    inbox.listen(pulse);
}

pub const panic = std.debug.FullPanic(fault);

fn fault(_: []const u8, _: ?usize) noreturn {
    inbox.stop(@intFromEnum(Status.InvalidState));
}
