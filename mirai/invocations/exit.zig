//! Exit invocation - Terminate Kata

const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const fd_utils = @import("../utils/fd.zig");
const handler = @import("handler.zig");
const kata_mod = @import("../kata/kata.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial.zig");

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const current_kata = sensei.get_current_kata() orelse return;
    const exit_code = ctx.rdi;

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
    kata_mod.dissolve_kata(current_kata.id);
    sensei.schedule();
}
