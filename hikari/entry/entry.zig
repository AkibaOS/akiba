//! Hikari EFI Executable Entry

const std = @import("std");

const force = @import("utils").analysis.force;
const hikari = @import("hikari");

comptime {
    force.all(hikari.assembly);
    force.all(hikari.disk);
    force.all(hikari.efi);
    force.all(hikari.fs);
    force.all(hikari.loader);
    force.all(hikari.paging);
    force.all(hikari.sequence);
}

pub fn main() std.os.uefi.Status {
    return hikari.sequence.entry.run();
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    hikari.assembly.halt.haltLoop();
}
