//! Mark invocation - Write to file descriptor

const handler = @import("handler.zig");
const sensei = @import("../kata/sensei.zig");
const kata_mod = @import("../kata/kata.zig");
const serial = @import("../drivers/serial.zig");
const fd_mod = @import("../kata/fd.zig");
const terminal = @import("../terminal.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const current_kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const fd = @as(u32, @truncate(ctx.rdi));
    const buffer_ptr = ctx.rsi;
    const count = ctx.rdx;

    serial.print("mark: fd=");
    serial.print_hex(fd);
    serial.print(", count=");
    serial.print_hex(count);
    serial.print(", buffer_ptr=");
    serial.print_hex(buffer_ptr);

    // Check what's at buffer_ptr RIGHT NOW in invoke()
    if (count > 0 and count <= 10) {
        serial.print(", bytes: ");
        const peek = @as([*]const u8, @ptrFromInt(buffer_ptr));
        var i: u64 = 0;
        while (i < count) : (i += 1) {
            serial.print_hex(peek[i]);
            serial.print(" ");
        }
    }
    serial.print("\n");

    if (fd >= 16 or current_kata.fd_table[fd].fd_type == .Closed) {
        serial.print("mark: invalid fd\n");
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    const bytes_written = write_to_fd(current_kata, fd, buffer_ptr, count) catch {
        serial.print("mark: write failed\n");
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    serial.print("mark: wrote ");
    serial.print_hex(bytes_written);
    serial.print(" bytes\n");
    ctx.rax = bytes_written;
}

fn write_to_fd(kata: *kata_mod.Kata, fd: u32, buffer_ptr: u64, count: u64) !u64 {
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

fn write_to_device(device: fd_mod.DeviceType, buffer_ptr: u64, count: u64) !u64 {
    // Copy userspace buffer to kernel space (stack gets reused during syscall processing)
    var kernel_buffer: [256]u8 = undefined;
    const copy_size = @min(count, 256);

    const src = @as([*]const u8, @ptrFromInt(buffer_ptr));
    var i: u64 = 0;
    while (i < copy_size) : (i += 1) {
        kernel_buffer[i] = src[i];
    }

    // Debug: show what we copied
    serial.print("write_to_device: copied ");
    serial.print_hex(copy_size);
    serial.print(" bytes: ");
    i = 0;
    while (i < copy_size and i < 10) : (i += 1) {
        serial.print_hex(kernel_buffer[i]);
        serial.print(" ");
    }
    serial.print("\n");

    switch (device) {
        .Stream, .Trace, .Console => {
            // Write to terminal from kernel buffer
            i = 0;
            while (i < copy_size) : (i += 1) {
                serial.print("write_to_device: calling terminal.put_char(");
                serial.print_hex(kernel_buffer[i]);
                serial.print(")\n");
                terminal.put_char(kernel_buffer[i]);
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
