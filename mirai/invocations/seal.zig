//! Seal invocation - Close file descriptor

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
    const current_kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const fd = @as(u32, @truncate(ctx.rdi));

    if (fd >= 16 or current_kata.fd_table[fd].fd_type == .Closed) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    fd_utils.close_fd(current_kata, fd, afs_instance);
    ctx.rax = 0;
}
