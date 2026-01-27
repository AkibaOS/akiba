//! Spawn invocation - Create new Kata from executable

const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const handler = @import("handler.zig");
const hikari = @import("../hikari/loader.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial.zig");
const string_utils = @import("../utils/string.zig");
const system = @import("../system/system.zig");

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const fs = afs_instance orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const path_ptr = ctx.rdi;
    const path_len = ctx.rsi;

    // Validate user pointer is in valid userspace range
    if (!system.is_valid_user_pointer(path_ptr)) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    if (path_len > system.limits.MAX_PATH_LENGTH) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    // Copy path from user space
    var path_buf: [system.limits.MAX_PATH_LENGTH]u8 = undefined;
    const path_src = @as([*]const u8, @ptrFromInt(path_ptr));
    for (0..path_len) |i| {
        path_buf[i] = path_src[i];
    }

    // Load and create new Kata
    const kata_id = hikari.load_program(fs, path_buf[0..path_len]) catch {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    ctx.rax = kata_id;
}
