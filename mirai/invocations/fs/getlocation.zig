//! Getlocation invocation - Get current stack location

const copy = @import("../../utils/mem/copy.zig");
const handler = @import("../handler.zig");
const kata_limits = @import("../../common/limits/kata.zig");
const memory_limits = @import("../../common/limits/memory.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei.zig");
const slice = @import("../../utils/mem/slice.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const buffer_ptr = ctx.rdi;
    const buffer_len = ctx.rsi;

    if (!memory_limits.is_valid_kata_pointer(buffer_ptr)) {
        return result.set_error(ctx);
    }

    const kata = sensei.get_current_kata() orelse return result.set_error(ctx);

    const location_len = kata.current_location_len;

    if (location_len == 0 or location_len > kata_limits.MAX_LOCATION_LENGTH) {
        const dest = slice.byte_ptr(buffer_ptr);
        dest[0] = '/';
        return result.set_value(ctx, 1);
    }

    if (location_len > buffer_len) {
        return result.set_error(ctx);
    }

    copy.to_ptr(buffer_ptr, kata.current_location[0..location_len]);
    result.set_value(ctx, location_len);
}
