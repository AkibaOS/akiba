//! Spawn invocation - Create new Kata from executable

const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const handler = @import("handler.zig");
const hikari = @import("../hikari/loader.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial.zig");
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
    const argv_ptr = ctx.rdx; // Optional: pointer to argument array
    const argc = ctx.r10; // Optional: argument count (0 if no args)

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
    const path = path_buf[0..path_len];

    // Build argument list
    // argv[0] = program path (replaces command name from shell)
    // argv[1...] = arguments from shell's argv[1...]
    var args: [system.limits.MAX_ARGS][]const u8 = undefined;
    var arg_count: usize = 1;
    args[0] = path; // argv[0] is always the program path

    // Copy additional arguments if provided (skip argv[0] from shell, start at argv[1])
    if (argc > 1 and argv_ptr != 0 and system.is_valid_user_pointer(argv_ptr)) {
        const user_argv = @as([*]const u64, @ptrFromInt(argv_ptr));

        // Start from index 1 to skip the command name (already replaced with full path)
        var i: usize = 1;
        while (i < argc and arg_count < system.limits.MAX_ARGS) : (i += 1) {
            const arg_ptr = user_argv[i];
            if (!system.is_valid_user_pointer(arg_ptr)) break;

            // Find string length (null-terminated)
            const arg_str = @as([*:0]const u8, @ptrFromInt(arg_ptr));
            var len: usize = 0;
            while (arg_str[len] != 0 and len < 256) : (len += 1) {}

            args[arg_count] = arg_str[0..len];
            arg_count += 1;
        }
    }

    // Load and create new Kata with arguments
    const kata_id = hikari.load_program_with_args(fs, path, args[0..arg_count]) catch {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    ctx.rax = kata_id;
}
