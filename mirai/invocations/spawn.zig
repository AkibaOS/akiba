//! Spawn invocation - Create new Kata from executable

const handler = @import("handler.zig");
const serial = @import("../drivers/serial.zig");
const hikari = @import("../hikari/loader.zig");
const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const string_utils = @import("../utils/string.zig");
const sensei = @import("../kata/sensei.zig");

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
    _ = ctx.rsi; // TODO: args support later

    // Validate user pointer
    if (path_ptr >= 0x0000800000000000) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    // Copy path from user space
    var path_buf: [256]u8 = undefined;
    const current_kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const path_len = string_utils.copy_string_from_user(current_kata, &path_buf, path_ptr) catch {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    // Load and create new Kata
    const kata_id = hikari.load_program(fs, path_buf[0..path_len]) catch {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    ctx.rax = kata_id;
}
