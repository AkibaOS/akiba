//! View invocation - Read from attachment

const copy = @import("../../utils/mem/copy.zig");
const fd_mod = @import("../../kata/fd.zig");
const handler = @import("../handler.zig");
const int = @import("../../utils/types/int.zig");
const kata_limits = @import("../../common/limits/kata.zig");
const kata_mod = @import("../../kata/kata.zig");
const keyboard = @import("../../drivers/keyboard.zig");
const random = @import("../../utils/random/xorshift.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei.zig");
const slice = @import("../../utils/mem/slice.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const kata = sensei.get_current_kata() orelse return result.set_error(ctx);

    const fd = int.u32_of(ctx.rdi);
    const buffer_ptr = ctx.rsi;
    const count = ctx.rdx;

    if (fd >= kata_limits.MAX_ATTACHMENTS or kata.fd_table[fd].fd_type == .Closed) {
        return result.set_error(ctx);
    }

    const bytes = view_from_attachment(kata, fd, buffer_ptr, count) catch return result.set_error(ctx);
    result.set_value(ctx, bytes);
}

fn view_from_attachment(kata: *kata_mod.Kata, fd: u32, buffer_ptr: u64, count: u64) !u64 {
    const entry = &kata.fd_table[fd];

    if (entry.fd_type == .Device) {
        const device = entry.device_type orelse return error.InvalidDevice;
        return view_from_device(device, buffer_ptr, count);
    }

    const unit_buffer = entry.buffer orelse return 0;
    const remaining = entry.file_size - entry.position;
    const to_view = @min(count, remaining);

    if (to_view == 0) return 0;

    const src = slice.from_ptr_const(u8, int.u64_of(unit_buffer.ptr) + entry.position, to_view);
    const dest = slice.from_ptr(u8, buffer_ptr, to_view);
    copy.bytes(dest, src);

    entry.position += to_view;
    return to_view;
}

fn view_from_device(device: fd_mod.DeviceType, buffer_ptr: u64, count: u64) !u64 {
    const dest = slice.byte_ptr(buffer_ptr);

    switch (device) {
        .Source => {
            var i: u64 = 0;
            while (i < count) : (i += 1) {
                if (keyboard.read_char()) |char| {
                    dest[i] = char;
                } else break;
            }
            return i;
        },
        .Zero => {
            copy.zero(slice.from_ptr(u8, buffer_ptr, count));
            return count;
        },
        .Chaos => {
            var i: u64 = 0;
            while (i < count) : (i += 1) {
                dest[i] = random.byte();
            }
            return count;
        },
        else => return error.CannotView,
    }
}
