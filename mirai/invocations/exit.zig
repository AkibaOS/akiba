//! Exit invocation - Terminate Kata

const handler = @import("handler.zig");
const sensei = @import("../kata/sensei.zig");
const kata_mod = @import("../kata/kata.zig");
const serial = @import("../drivers/serial.zig");
const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const fd_utils = @import("../utils/fd.zig");

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const current_kata = sensei.get_current_kata() orelse return;
    const exit_code = ctx.rdi;

    serial.print("Invocation: exit\n");
    serial.print("  Kata exit with code: ");
    serial.print_hex(exit_code);
    serial.print("\n");

    // Close all open file descriptors
    var i: u32 = 0;
    while (i < 16) : (i += 1) {
        if (current_kata.fd_table[i].fd_type == .Regular) {
            fd_utils.close_fd(current_kata, i, afs_instance);
        }
    }

    // Store exit code before dissolving
    current_kata.exit_code = exit_code;

    // Dissolve the Kata
    serial.print("  Dissolving Kata ");
    serial.print_hex(current_kata.id);
    serial.print("\n");

    kata_mod.dissolve_kata(current_kata.id);
    sensei.schedule();
}
