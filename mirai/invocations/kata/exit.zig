//! Exit invocation - Dissolve Kata

const afs = @import("../../fs/afs.zig");
const ahci = @import("../../drivers/ahci.zig");
const attachment = @import("../../utils/kata/attachment.zig");
const handler = @import("../handler.zig");
const kata_limits = @import("../../common/limits/kata.zig");
const kata_mod = @import("../../kata/kata.zig");
const sensei = @import("../../kata/sensei.zig");

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const kata = sensei.get_current_kata() orelse return;
    const exit_code = ctx.rdi;

    var i: u32 = 0;
    while (i < kata_limits.MAX_ATTACHMENTS) : (i += 1) {
        if (kata.fd_table[i].fd_type == .Regular) {
            attachment.seal(kata, i, afs_instance);
        }
    }

    kata.exit_code = exit_code;
    kata_mod.dissolve_kata(kata.id);
    sensei.schedule();
}
