//! Standalone AHCI Device Driver Entry

const std = @import("std");

const assembly = @import("personaasm");
const disk = @import("ahci").device.disk;
const service = @import("ahci").service.inbox;

const Status = @import("shared").persona.types.invocation.Status;

comptime {
    _ = assembly.entry.ahci.ahci_entry;
}

export fn ahci_main() callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const device = disk.verify() catch service.stop(@intFromEnum(Status.InvalidState));
    service.listen(device);
}

pub const panic = std.debug.FullPanic(fault);

fn fault(_: []const u8, _: ?usize) noreturn {
    service.stop(@intFromEnum(Status.InvalidState));
}
