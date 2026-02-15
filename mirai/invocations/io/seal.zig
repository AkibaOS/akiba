//! Seal invocation - Close attachment

const afs = @import("../../fs/afs/afs.zig");
const ahci = @import("../../drivers/ahci/ahci.zig");
const attachment = @import("../../utils/kata/attachment.zig");
const handler = @import("../handler.zig");
const int = @import("../../utils/types/int.zig");
const kata_limits = @import("../../common/limits/kata.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei/sensei.zig");

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const kata = sensei.get_current_kata() orelse return result.set_error(ctx);

    const fd = int.u32_of(ctx.rdi);

    if (fd >= kata_limits.MAX_ATTACHMENTS or kata.attachments[fd].attachment_type == .Closed) {
        return result.set_error(ctx);
    }

    attachment.seal(kata, fd, afs_instance);
    result.set_ok(ctx);
}
