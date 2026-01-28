//! Mark invocation - Write to file descriptor

const fd_mod = @import("../kata/fd.zig");
const handler = @import("handler.zig");
const kata_mod = @import("../kata/kata.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial.zig");
const system = @import("../system/system.zig");
const terminal = @import("../terminal.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const current_kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const fd = @as(u32, @truncate(ctx.rdi));
    const buffer_ptr = ctx.rsi;
    const count = ctx.rdx;
    const color = @as(u32, @truncate(ctx.r10));

    if (fd >= system.limits.MAX_FILE_DESCRIPTORS or current_kata.fd_table[fd].fd_type == .Closed) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    const bytes_written = write_to_fd(current_kata, fd, buffer_ptr, count, color) catch {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    ctx.rax = bytes_written;
}

fn write_to_fd(kata: *kata_mod.Kata, fd: u32, buffer_ptr: u64, count: u64, color: u32) !u64 {
    // Validate count is reasonable
    if (count == 0) return 0;
    if (count > system.limits.MAX_WRITE_SIZE) return error.WriteTooLarge;

    const fd_entry = &kata.fd_table[fd];

    // Device files
    if (fd_entry.fd_type == .Device) {
        const device = fd_entry.device_type orelse return error.InvalidDevice;
        return write_to_device(device, buffer_ptr, count, color);
    }

    // Regular files - mark as dirty for later flush
    // File writes will be implemented when file I/O buffering is added
    fd_entry.dirty = true;
    return count;
}

fn write_to_device(device: fd_mod.DeviceType, buffer_ptr: u64, count: u64, color: u32) !u64 {
    // Validate user buffer pointer
    if (!system.is_valid_user_pointer(buffer_ptr)) {
        return error.InvalidPointer;
    }

    // Copy userspace buffer to kernel space to prevent stack corruption
    var kernel_buffer: [system.limits.KERNEL_COPY_BUFFER_SIZE]u8 = undefined;
    const copy_size = @min(count, system.limits.KERNEL_COPY_BUFFER_SIZE);

    const src = @as([*]const u8, @ptrFromInt(buffer_ptr));
    var i: u64 = 0;
    while (i < copy_size) : (i += 1) {
        kernel_buffer[i] = src[i];
    }

    switch (device) {
        .Stream, .Trace, .Console => {
            // Write to terminal from kernel buffer with color
            i = 0;
            while (i < copy_size) : (i += 1) {
                terminal.put_char_color(kernel_buffer[i], color);
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
