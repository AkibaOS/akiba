//! Attach invocation - Open attachment

const afs = @import("../../fs/afs/afs.zig");
const ahci = @import("../../drivers/ahci/ahci.zig");
const attachment = @import("../../utils/kata/attachment.zig");
const compare = @import("../../utils/string/compare.zig");
const copy = @import("../../utils/mem/copy.zig");
const fd_mod = @import("../../kata/fd.zig");
const handler = @import("../handler.zig");
const heap = @import("../../memory/heap.zig");
const int = @import("../../utils/types/int.zig");
const kata_mod = @import("../../kata/kata.zig");
const path = @import("../../utils/fs/path.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei.zig");
const string_copy = @import("../../utils/string/copy.zig");

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const kata = sensei.get_current_kata() orelse return result.set_error(ctx);

    const location_ptr = ctx.rdi;
    const flags = int.u32_of(ctx.rsi);

    var location_buf: [256]u8 = undefined;
    const location_len = string_copy.from_kata(&location_buf, location_ptr) catch return result.set_error(ctx);
    const location = location_buf[0..location_len];

    if (path.is_device(location)) {
        const fd = open_device(kata, location, flags) catch return result.set_error(ctx);
        return result.set_value(ctx, fd);
    }

    const fd = open_unit(kata, location, flags) catch return result.set_error(ctx);
    result.set_value(ctx, fd);
}

fn open_device(kata: *kata_mod.Kata, location: []const u8, flags: u32) !u32 {
    const name = path.device_name(location);

    const device_type: fd_mod.DeviceType =
        if (compare.equals(name, "source")) .Source else if (compare.equals(name, "stream")) .Stream else if (compare.equals(name, "trace")) .Trace else if (compare.equals(name, "void")) .Void else if (compare.equals(name, "chaos")) .Chaos else if (compare.equals(name, "zero")) .Zero else if (compare.equals(name, "console")) .Console else return error.UnknownDevice;

    const fd = try attachment.allocate(kata);
    kata.fd_table[fd] = fd_mod.FileDescriptor{
        .fd_type = .Device,
        .device_type = device_type,
        .flags = flags,
    };

    return fd;
}

fn open_unit(kata: *kata_mod.Kata, location: []const u8, flags: u32) !u32 {
    const fs = afs_instance orelse return error.NoFilesystem;

    var full_location_buf: [512]u8 = undefined;
    const full_location = path.resolve(kata, location, &full_location_buf);

    const fd = try attachment.allocate(kata);

    var unit_buffer: [1024 * 1024]u8 = undefined;
    const bytes_read = fs.view_unit_at(full_location, &unit_buffer) catch {
        if (flags & fd_mod.CREATE != 0) {
            fs.create_unit(full_location) catch return error.CannotCreate;

            kata.fd_table[fd] = fd_mod.FileDescriptor{
                .fd_type = .Regular,
                .file_size = 0,
                .position = 0,
                .flags = flags,
                .path_len = location.len,
            };
            copy.bytes(kata.fd_table[fd].path[0..location.len], location);
            return fd;
        }
        return error.UnitNotFound;
    };

    const unit_data = heap.alloc(bytes_read) orelse return error.OutOfMemory;
    copy.bytes(unit_data[0..bytes_read], unit_buffer[0..bytes_read]);

    kata.fd_table[fd] = fd_mod.FileDescriptor{
        .fd_type = .Regular,
        .buffer = unit_data[0..bytes_read],
        .file_size = bytes_read,
        .position = if (flags & fd_mod.EXTEND != 0) bytes_read else 0,
        .flags = flags,
        .path_len = location.len,
    };
    copy.bytes(kata.fd_table[fd].path[0..location.len], location);

    return fd;
}
