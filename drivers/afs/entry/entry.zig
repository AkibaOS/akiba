//! Standalone AFS Driver Entry

const std = @import("std");

const afs = @import("shared").afs;
const assembly = @import("personaasm");
const inbox = @import("afs").service.inbox;
const mount = @import("afs").device.mount;

const Status = @import("shared").persona.types.invocation.Status;

var scratch: [afs.constants.sizes.MAXIMUM_CELL_SIZE]u8 = undefined;

comptime {
    _ = assembly.entry.afs.afs_entry;
}

export fn afs_main(address: u64) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    var settings = mount.parameters(address) catch inbox.stop(@intFromEnum(Status.InvalidState));
    var sectors = mount.open(&settings, &scratch) catch inbox.stop(@intFromEnum(Status.InvalidState));
    const catalog = afs.read.catalog.mount(afs.read.sectors.reader(&sectors), &scratch) catch inbox.stop(@intFromEnum(Status.InvalidState));
    inbox.listen(&catalog, settings.PulseID, &scratch);
}

pub const panic = std.debug.FullPanic(fault);

fn fault(_: []const u8, _: ?usize) noreturn {
    inbox.stop(@intFromEnum(Status.InvalidState));
}
