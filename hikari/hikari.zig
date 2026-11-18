//! Hikari UEFI Bootloader for AkibaOS

const std = @import("std");

const force = @import("utils").analysis.force;

pub const assembly = @import("asm/asm.zig");
pub const disk = @import("disk/disk.zig");
pub const efi = @import("efi/efi.zig");
pub const fs = @import("fs/fs.zig");
pub const loader = @import("loader/loader.zig");
pub const paging = @import("paging/paging.zig");
pub const sequence = @import("sequence/sequence.zig");

comptime {
    force.all(assembly);
    force.all(disk);
    force.all(efi);
    force.all(fs);
    force.all(loader);
    force.all(paging);
    force.all(sequence);
}

pub fn main() std.os.uefi.Status {
    const image_handle: efi.types.base.Handle = @ptrCast(std.os.uefi.handle);
    const system_table: *efi.types.services.system.SystemTable = @ptrCast(std.os.uefi.system_table);
    return @enumFromInt(sequence.run.run(image_handle, system_table));
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    _ = message;
    _ = stack_trace;
    _ = return_address;
    assembly.halt.haltLoop();
}
