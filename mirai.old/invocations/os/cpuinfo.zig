//! CPUINFO invocation - Get CPU model string

const cpuid = @import("../../asm/cpuid.zig");
const handler = @import("../handler.zig");
const result = @import("../../utils/types/result.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const buffer_ptr: [*]u8 = @ptrFromInt(ctx.rdi);
    const buffer_len: usize = @intCast(ctx.rsi);

    if (buffer_len < 48) {
        result.set_error(ctx);
        return;
    }

    if (!cpuid.has_brand_string()) {
        const generic = "Unknown CPU";
        for (generic, 0..) |c, i| {
            buffer_ptr[i] = c;
        }
        result.set_value(ctx, generic.len);
        return;
    }

    var brand: [48]u8 = undefined;
    cpuid.get_brand_string(&brand);

    // Trim leading spaces
    var start: usize = 0;
    while (start < 48 and brand[start] == ' ') : (start += 1) {}

    // Trim trailing spaces and nulls
    var end: usize = 48;
    while (end > start and (brand[end - 1] == ' ' or brand[end - 1] == 0)) : (end -= 1) {}

    const trimmed_len = end - start;
    for (0..trimmed_len) |i| {
        buffer_ptr[i] = brand[start + i];
    }

    result.set_value(ctx, trimmed_len);
}
