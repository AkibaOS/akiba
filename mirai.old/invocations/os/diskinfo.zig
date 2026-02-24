//! DISKINFO invocation - Get disk usage information

const afs = @import("../../fs/afs/afs.zig");
const ahci = @import("../../drivers/ahci/ahci.zig");
const handler = @import("../handler.zig");
const result = @import("../../utils/types/result.zig");

var fs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    fs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const total_ptr: *u64 = @ptrFromInt(ctx.rdi);
    const used_ptr: *u64 = @ptrFromInt(ctx.rsi);

    if (fs_instance) |fs| {
        const info = fs.get_disk_info();
        total_ptr.* = info.total_bytes;
        used_ptr.* = info.used_bytes;
        result.set_ok(ctx);
    } else {
        result.set_error(ctx);
    }
}
