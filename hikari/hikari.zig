//! Hikari UEFI Bootloader for AkibaOS

const std = @import("std");

pub const efi = @import("efi/efi.zig");
pub const disk = @import("disk/disk.zig");
pub const fs = @import("fs/fs.zig");
pub const loader = @import("loader/loader.zig");
pub const display = @import("display/display.zig");
pub const menu = @import("menu/menu.zig");
pub const paging = @import("paging/paging.zig");
pub const boot = @import("boot/boot.zig");
pub const asm_ops = @import("asm/asm.zig");
pub const sequence = @import("sequence/sequence.zig");

pub fn main() void {
    const image_handle: efi.types.Handle = @ptrCast(std.os.uefi.handle);
    const system_table: *efi.services.SystemTable = @ptrCast(std.os.uefi.system_table);
    _ = sequence.run(image_handle, system_table);
}

pub fn panic(msg: []const u8, stack_trace: ?*@import("std").builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = stack_trace;
    _ = ret_addr;
    asm_ops.halt();
}
