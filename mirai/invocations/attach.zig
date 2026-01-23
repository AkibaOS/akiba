//! Attach invocation - Open file descriptor

const handler = @import("handler.zig");
const sensei = @import("../kata/sensei.zig");
const kata_mod = @import("../kata/kata.zig");
const serial = @import("../drivers/serial.zig");
const fd_mod = @import("../kata/fd.zig");
const heap = @import("../memory/heap.zig");
const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");

const path_utils = @import("../utils/path.zig");
const string_utils = @import("../utils/string.zig");
const fd_utils = @import("../utils/fd.zig");

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const current_kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const path_ptr = ctx.rdi;
    const flags = @as(u32, @truncate(ctx.rsi));

    var path_buffer: [256]u8 = undefined;
    const path_len = string_utils.copy_string_from_user(current_kata, &path_buffer, path_ptr) catch {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };
    const path = path_buffer[0..path_len];

    if (path_utils.is_device_path(path)) {
        const fd = open_device(current_kata, path, flags) catch {
            ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
            return;
        };
        ctx.rax = fd;
        return;
    }

    const fd = open_regular_file(current_kata, path, flags) catch {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    ctx.rax = fd;
}

fn open_device(kata: *kata_mod.Kata, path: []const u8, flags: u32) !u32 {
    const device_name = path[16..];

    const device_type: fd_mod.DeviceType = if (string_utils.strings_equal(device_name, "source"))
        .Source
    else if (string_utils.strings_equal(device_name, "stream"))
        .Stream
    else if (string_utils.strings_equal(device_name, "trace"))
        .Trace
    else if (string_utils.strings_equal(device_name, "void"))
        .Void
    else if (string_utils.strings_equal(device_name, "chaos"))
        .Chaos
    else if (string_utils.strings_equal(device_name, "zero"))
        .Zero
    else if (string_utils.strings_equal(device_name, "console"))
        .Console
    else {
        return error.UnknownDevice;
    };

    const fd = try fd_utils.allocate_fd(kata);
    kata.fd_table[fd] = fd_mod.FileDescriptor{
        .fd_type = .Device,
        .device_type = device_type,
        .flags = flags,
    };

    return fd;
}

fn open_regular_file(kata: *kata_mod.Kata, path: []const u8, flags: u32) !u32 {
    const fs = afs_instance orelse return error.NoFilesystem;

    var full_path_buffer: [512]u8 = undefined;
    const full_path = path_utils.resolve_path(kata, path, &full_path_buffer);

    const fd = try fd_utils.allocate_fd(kata);

    var file_buffer: [1024 * 1024]u8 = undefined;
    const bytes_read = fs.read_file_by_path(full_path, &file_buffer) catch {
        if (flags & fd_mod.CREATE != 0) {
            fs.create_file(full_path) catch {
                return error.CannotCreate;
            };

            kata.fd_table[fd] = fd_mod.FileDescriptor{
                .fd_type = .Regular,
                .file_size = 0,
                .position = 0,
                .flags = flags,
                .path_len = path.len,
            };
            @memcpy(kata.fd_table[fd].path[0..path.len], path);
            return fd;
        }

        return error.FileNotFound;
    };

    const file_data = heap.alloc(bytes_read) orelse return error.OutOfMemory;
    @memcpy(file_data[0..bytes_read], file_buffer[0..bytes_read]);

    kata.fd_table[fd] = fd_mod.FileDescriptor{
        .fd_type = .Regular,
        .buffer = file_data[0..bytes_read],
        .file_size = bytes_read,
        .position = if (flags & fd_mod.EXTEND != 0) bytes_read else 0,
        .flags = flags,
        .path_len = path.len,
    };
    @memcpy(kata.fd_table[fd].path[0..path.len], path);

    return fd;
}
