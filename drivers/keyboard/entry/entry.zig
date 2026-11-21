//! Installed Keyboard Driver Entry

const std = @import("std");

const inbox = @import("keyboard").service.inbox;
const startup = @import("shared").launch.startup;

const Status = @import("shared").persona.types.invocation.Status;

export fn persona_main(address: u64) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const supervisor = startup.supervisor(address) catch inbox.stop(@intFromEnum(Status.InvalidArgument));
    inbox.listen(supervisor);
}

pub const panic = std.debug.FullPanic(fault);

fn fault(_: []const u8, _: ?usize) noreturn {
    inbox.stop(@intFromEnum(Status.InvalidState));
}
