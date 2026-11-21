//! Standalone Pulse ELF Entry

const std = @import("std");

const assembly = @import("personaasm");
const asset = @import("shared").pulse.strings.bootstrap;
const bootstrap = @import("pulse").supervision.bootstrap;
const drivers = @import("pulse").supervision.driver;
const run = @import("pulse").supervision.inbox;

const Status = @import("shared").persona.types.invocation.Status;

const AFS = @embedFile(asset.AFS_IMPORT);
export const afs_bootstrap: [AFS.len]u8 linksection(asset.AFS_SECTION) = AFS[0..AFS.len].*;
const AHCI = @embedFile(asset.AHCI_IMPORT);
export const ahci_bootstrap: [AHCI.len]u8 linksection(asset.AHCI_SECTION) = AHCI[0..AHCI.len].*;
const WEAVER = @embedFile(asset.WEAVER_IMPORT);
export const weaver_bootstrap: [WEAVER.len]u8 linksection(asset.WEAVER_SECTION) = WEAVER[0..WEAVER.len].*;

comptime {
    _ = assembly.entry.pulse.pulse_entry;
}

export fn pulse_main() callconv(.{ .x86_64_sysv = .{} }) noreturn {
    bootstrap.start();
    const ahci = drivers.ahci.start();
    _ = drivers.afs.start(ahci);
    run.listen();
}

pub const panic = std.debug.FullPanic(fault);

fn fault(_: []const u8, _: ?usize) noreturn {
    run.stop(@intFromEnum(Status.InvalidState));
}
