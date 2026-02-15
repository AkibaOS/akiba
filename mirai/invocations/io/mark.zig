//! Mark invocation - Write to attachment

const copy = @import("../../utils/mem/copy.zig");
const fd_mod = @import("../../kata/attachment.zig");
const handler = @import("../handler.zig");
const int = @import("../../utils/types/int.zig");
const io_limits = @import("../../common/limits/io.zig");
const kata_limits = @import("../../common/limits/kata.zig");
const kata_mod = @import("../../kata/kata.zig");
const memory_limits = @import("../../common/limits/memory.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei/sensei.zig");
const terminal = @import("../../graphics/terminal/terminal.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const kata = sensei.get_current_kata() orelse return result.set_error(ctx);

    const fd = int.u32_of(ctx.rdi);
    const buffer_ptr = ctx.rsi;
    const count = ctx.rdx;
    const color = int.u32_of(ctx.r10);

    if (fd >= kata_limits.MAX_ATTACHMENTS or kata.attachments[fd].attachment_type == .Closed) {
        return result.set_error(ctx);
    }

    const bytes = mark_to_attachment(kata, fd, buffer_ptr, count, color) catch return result.set_error(ctx);
    result.set_value(ctx, bytes);
}

fn mark_to_attachment(kata: *kata_mod.Kata, fd: u32, buffer_ptr: u64, count: u64, color: u32) !u64 {
    if (count == 0) return 0;
    if (count > io_limits.MAX_MARK_SIZE) return error.MarkTooLarge;

    const entry = &kata.attachments[fd];

    if (entry.attachment_type == .Device) {
        const device = entry.device_type orelse return error.InvalidDevice;
        return mark_to_device(device, buffer_ptr, count, color);
    }

    entry.dirty = true;
    return count;
}

fn mark_to_device(device: fd_mod.DeviceType, buffer_ptr: u64, count: u64, color: u32) !u64 {
    if (!memory_limits.is_valid_kata_pointer(buffer_ptr)) {
        return error.InvalidPointer;
    }

    var mirai_buffer: [io_limits.MIRAI_COPY_BUFFER_SIZE]u8 = undefined;
    const copy_size = @min(count, io_limits.MIRAI_COPY_BUFFER_SIZE);

    copy.from_ptr(&mirai_buffer, buffer_ptr, copy_size);

    switch (device) {
        .Stream, .Trace, .Console => {
            for (mirai_buffer[0..copy_size]) |c| {
                terminal.put_char_color(c, color);
            }
            return count;
        },
        .Void => return count,
        else => return error.CannotMark,
    }
}
