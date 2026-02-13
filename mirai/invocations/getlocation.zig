//! Getlocation invocation - Get current stack location

const handler = @import("handler.zig");
const sensei = @import("../kata/sensei.zig");
const system = @import("../system/system.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const buffer_ptr = ctx.rdi;
    const buffer_len = ctx.rsi;

    if (!system.is_valid_user_pointer(buffer_ptr)) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    const kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const location_len = kata.current_location_len;

    if (location_len == 0 or location_len > 256) {
        const dest = @as([*]u8, @ptrFromInt(buffer_ptr));
        dest[0] = '/';
        ctx.rax = 1;
        return;
    }

    if (location_len > buffer_len) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    const dest = @as([*]u8, @ptrFromInt(buffer_ptr));
    for (0..location_len) |i| {
        dest[i] = kata.current_location[i];
    }

    ctx.rax = location_len;
}
