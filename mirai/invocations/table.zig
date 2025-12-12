//! Invocation Table - Implementation of all Akiba invocations

const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const fd_mod = @import("../kata/fd.zig");
const handler = @import("handler.zig");
const heap = @import("../memory/heap.zig");
const kata_mod = @import("../kata/kata.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial.zig");
const terminal = @import("../terminal.zig");

const InvocationContext = handler.InvocationContext;
const Kata = kata_mod.Kata;

// Global AFS instance (set by boot sequence)
var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

// Invocation 0x01: exit
pub fn invoke_exit(ctx: *InvocationContext) void {
    const current_kata = sensei.get_current_kata() orelse return;
    const exit_code = ctx.rdi;

    serial.print("Invocation: exit\n");
    serial.print("Kata exit with code: ");
    serial.print_hex(exit_code);
    serial.print("\n");

    // Close all open file descriptors
    var i: u32 = 0;
    while (i < 16) : (i += 1) {
        if (current_kata.fd_table[i].fd_type == .Regular) {
            close_fd(current_kata, i);
        }
    }

    // Dissolve the Kata
    serial.print("Dissolving Kata ");
    serial.print_hex(current_kata.id);
    serial.print("\n");

    kata_mod.dissolve_kata(current_kata.id);

    // Return to scheduler (this won't actually return)
    sensei.schedule();
}

// Invocation 0x02: attach (open file)
// RDI = path pointer, RSI = flags
// Returns: fd in RAX, or -1 on error
pub fn invoke_attach(ctx: *InvocationContext) void {
    const current_kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const path_ptr = ctx.rdi;
    const flags = @as(u32, @truncate(ctx.rsi));

    // Validate and copy path from user space
    var path_buffer: [256]u8 = undefined;
    const path_len = copy_string_from_user(current_kata, &path_buffer, path_ptr) catch {
        serial.print("attach: Invalid path pointer\n");
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };
    const path = path_buffer[0..path_len];

    serial.print("Invocation: attach\n");
    serial.print("  Path: ");
    serial.print(path);
    serial.print("\n  Flags: ");
    serial.print_hex(flags);
    serial.print("\n");

    // Check if it's a device file
    if (is_device_path(path)) {
        const fd = open_device(current_kata, path, flags) catch {
            ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
            return;
        };
        serial.print("  Opened device fd ");
        serial.print_hex(fd);
        serial.print("\n");
        ctx.rax = fd;
        return;
    }

    // Regular file
    const fd = open_regular_file(current_kata, path, flags) catch {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    serial.print("  Opened fd ");
    serial.print_hex(fd);
    serial.print("\n");
    ctx.rax = fd;
}

// Invocation 0x03: seal (close file)
// RDI = fd
pub fn invoke_seal(ctx: *InvocationContext) void {
    const current_kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const fd = @as(u32, @truncate(ctx.rdi));

    serial.print("Invocation: seal\n");
    serial.print("  fd: ");
    serial.print_hex(fd);
    serial.print("\n");

    if (fd >= 16 or current_kata.fd_table[fd].fd_type == .Closed) {
        serial.print("  Invalid fd\n");
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    close_fd(current_kata, fd);
    ctx.rax = 0;
}

// Invocation 0x04: view (read from file)
// RDI = fd, RSI = buffer pointer, RDX = count
// Returns: bytes read in RAX, or -1 on error
pub fn invoke_view(ctx: *InvocationContext) void {
    const current_kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const fd = @as(u32, @truncate(ctx.rdi));
    const buffer_ptr = ctx.rsi;
    const count = ctx.rdx;

    serial.print("Invocation: view\n");
    serial.print("  fd: ");
    serial.print_hex(fd);
    serial.print(", count: ");
    serial.print_hex(count);
    serial.print("\n");

    if (fd >= 16 or current_kata.fd_table[fd].fd_type == .Closed) {
        serial.print("  Invalid fd\n");
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    const bytes_read = read_from_fd(current_kata, fd, buffer_ptr, count) catch {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    serial.print("  Read ");
    serial.print_hex(bytes_read);
    serial.print(" bytes\n");
    ctx.rax = bytes_read;
}

// Invocation 0x05: mark (write to file)
// RDI = fd, RSI = buffer pointer, RDX = count
// Returns: bytes written in RAX, or -1 on error
pub fn invoke_mark(ctx: *InvocationContext) void {
    const current_kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const fd = @as(u32, @truncate(ctx.rdi));
    const buffer_ptr = ctx.rsi;
    const count = ctx.rdx;

    serial.print("Invocation: mark\n");
    serial.print("  fd: ");
    serial.print_hex(fd);
    serial.print(", count: ");
    serial.print_hex(count);
    serial.print("\n");

    if (fd >= 16 or current_kata.fd_table[fd].fd_type == .Closed) {
        serial.print("  Invalid fd\n");
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    const bytes_written = write_to_fd(current_kata, fd, buffer_ptr, count) catch {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    serial.print("  Wrote ");
    serial.print_hex(bytes_written);
    serial.print(" bytes\n");
    ctx.rax = bytes_written;
}

// === HELPER FUNCTIONS ===

fn is_device_path(path: []const u8) bool {
    return path.len > 16 and
        path[0] == '/' and
        path[1] == 's' and
        path[2] == 'y' and
        path[3] == 's' and
        path[4] == 't' and
        path[5] == 'e' and
        path[6] == 'm' and
        path[7] == '/' and
        path[8] == 'd' and
        path[9] == 'e' and
        path[10] == 'v' and
        path[11] == 'i' and
        path[12] == 'c' and
        path[13] == 'e' and
        path[14] == 's' and
        path[15] == '/';
}

fn open_device(kata: *Kata, path: []const u8, flags: u32) !u32 {
    const device_name = path[16..];

    const device_type: fd_mod.DeviceType = if (strings_equal(device_name, "source"))
        .Source
    else if (strings_equal(device_name, "stream"))
        .Stream
    else if (strings_equal(device_name, "trace"))
        .Trace
    else if (strings_equal(device_name, "void"))
        .Void
    else if (strings_equal(device_name, "chaos"))
        .Chaos
    else if (strings_equal(device_name, "zero"))
        .Zero
    else if (strings_equal(device_name, "console"))
        .Console
    else {
        serial.print("  Unknown device: ");
        serial.print(device_name);
        serial.print("\n");
        return error.UnknownDevice;
    };

    const fd = try allocate_fd(kata);
    kata.fd_table[fd] = fd_mod.FileDescriptor{
        .fd_type = .Device,
        .device_type = device_type,
        .flags = flags,
    };

    return fd;
}

fn open_regular_file(kata: *Kata, path: []const u8, flags: u32) !u32 {
    const fs = afs_instance orelse return error.NoFilesystem;

    // Resolve path
    var full_path_buffer: [512]u8 = undefined;
    const full_path = resolve_path(kata, path, &full_path_buffer);

    // Allocate fd
    const fd = try allocate_fd(kata);

    // Try to read file
    var file_buffer: [1024 * 1024]u8 = undefined;
    const bytes_read = fs.read_file_by_path(full_path, &file_buffer) catch |err| {
        // File doesn't exist
        if (flags & fd_mod.CREATE != 0) {
            // Create new file
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

        serial.print("  Cannot open: ");
        serial.print(@errorName(err));
        serial.print("\n");
        return error.FileNotFound;
    };

    // Allocate kernel buffer for file
    const file_data = heap.alloc(bytes_read) orelse return error.OutOfMemory;
    @memcpy(file_data[0..bytes_read], file_buffer[0..bytes_read]);

    // Setup file descriptor
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

fn close_fd(kata: *Kata, fd: u32) void {
    const fd_entry = &kata.fd_table[fd];

    // If regular file and dirty, write back to AFS
    if (fd_entry.fd_type == .Regular and fd_entry.dirty) {
        if (fd_entry.buffer) |buffer| {
            const fs = afs_instance orelse return;
            const path = fd_entry.path[0..fd_entry.path_len];

            // Resolve path
            var full_path_buffer: [512]u8 = undefined;
            const full_path = resolve_path(kata, path, &full_path_buffer);

            fs.write_file(full_path, buffer) catch {
                serial.print("  Warning: Could not write back file\n");
            };

            // Free buffer
            heap.free(@ptrCast(buffer.ptr), buffer.len);
        }
    }

    // Clear descriptor
    fd_entry.* = fd_mod.FileDescriptor{};
}

fn read_from_fd(kata: *Kata, fd: u32, buffer_ptr: u64, count: u64) !u64 {
    const fd_entry = &kata.fd_table[fd];

    // Device files
    if (fd_entry.fd_type == .Device) {
        const device = fd_entry.device_type orelse return error.InvalidDevice;
        return read_from_device(device, buffer_ptr, count);
    }

    // Regular files
    const file_buffer = fd_entry.buffer orelse return 0;
    const remaining = fd_entry.file_size - fd_entry.position;
    const to_read = @min(count, remaining);

    if (to_read == 0) return 0;

    // Copy from kernel buffer to user buffer
    const src = file_buffer.ptr + fd_entry.position;
    const dest = @as([*]u8, @ptrFromInt(buffer_ptr));
    @memcpy(dest[0..to_read], src[0..to_read]);

    fd_entry.position += to_read;
    return to_read;
}

fn write_to_fd(kata: *Kata, fd: u32, buffer_ptr: u64, count: u64) !u64 {
    const fd_entry = &kata.fd_table[fd];

    // Device files
    if (fd_entry.fd_type == .Device) {
        const device = fd_entry.device_type orelse return error.InvalidDevice;
        return write_to_device(device, buffer_ptr, count);
    }

    // Regular files - for now, just mark as dirty
    // TODO: Proper buffer management with reallocation
    fd_entry.dirty = true;
    return count;
}

fn read_from_device(device: fd_mod.DeviceType, buffer_ptr: u64, count: u64) !u64 {
    switch (device) {
        .Source => {
            // TODO: Keyboard input
            return 0;
        },
        .Zero => {
            // Fill with zeros
            const dest = @as([*]u8, @ptrFromInt(buffer_ptr));
            var i: u64 = 0;
            while (i < count) : (i += 1) {
                dest[i] = 0;
            }
            return count;
        },
        .Chaos => {
            // TODO: Random data
            return 0;
        },
        else => return error.CannotRead,
    }
}

fn write_to_device(device: fd_mod.DeviceType, buffer_ptr: u64, count: u64) !u64 {
    switch (device) {
        .Stream, .Trace => {
            // Write to terminal
            const src = @as([*]const u8, @ptrFromInt(buffer_ptr));
            var i: u64 = 0;
            while (i < count) : (i += 1) {
                terminal.put_char(src[i]);
            }
            return count;
        },
        .Console => {
            // Write to terminal
            const src = @as([*]const u8, @ptrFromInt(buffer_ptr));
            var i: u64 = 0;
            while (i < count) : (i += 1) {
                terminal.put_char(src[i]);
            }
            return count;
        },
        .Void => {
            // Discard all writes
            return count;
        },
        else => return error.CannotWrite,
    }
}

fn allocate_fd(kata: *Kata) !u32 {
    var i: u32 = 3;
    while (i < 16) : (i += 1) {
        if (kata.fd_table[i].fd_type == .Closed) {
            return i;
        }
    }
    return error.TooManyFiles;
}

fn resolve_path(kata: *Kata, path: []const u8, buffer: []u8) []const u8 {
    if (path[0] == '/') {
        // Absolute path
        @memcpy(buffer[0..path.len], path);
        return buffer[0..path.len];
    }

    // Relative path
    const cwd = kata.current_location[0..kata.current_location_len];
    var len: usize = 0;

    @memcpy(buffer[0..cwd.len], cwd);
    len += cwd.len;

    if (cwd[cwd.len - 1] != '/') {
        buffer[len] = '/';
        len += 1;
    }

    @memcpy(buffer[len .. len + path.len], path);
    len += path.len;

    return buffer[0..len];
}

fn copy_string_from_user(_: *Kata, dest: []u8, user_ptr: u64) !usize {
    // TODO: Validate user pointer
    const src = @as([*:0]const u8, @ptrFromInt(user_ptr));
    var len: usize = 0;
    while (src[len] != 0 and len < dest.len) : (len += 1) {
        dest[len] = src[len];
    }
    return len;
}

fn strings_equal(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return true;
}
