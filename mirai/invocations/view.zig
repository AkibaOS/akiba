//! View invocation - Read from file descriptor

const handler = @import("handler.zig");
const sensei = @import("../kata/sensei.zig");
const kata_mod = @import("../kata/kata.zig");
const serial = @import("../drivers/serial.zig");
const fd_mod = @import("../kata/fd.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
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

fn read_from_fd(kata: *kata_mod.Kata, fd: u32, buffer_ptr: u64, count: u64) !u64 {
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
