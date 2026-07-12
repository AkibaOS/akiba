//! Render Stack Trace

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const messages = @import("../strings/strings.zig").messages;

const Context = types.Context;

pub fn render(context: *const Context) void {
    serial.printf(messages.STACK_TRACE_HEADER, .{});

    var rbp = context.rbp;
    var depth: usize = 0;
    const max_depth: usize = 20;

    while (rbp != 0 and depth < max_depth) {
        const frame_ptr: [*]const u64 = @ptrFromInt(rbp);

        const return_address = frame_ptr[1];
        if (return_address == 0) break;

        serial.printf("  [%d] %x\n", .{ depth, return_address });

        const next_rbp = frame_ptr[0];
        if (next_rbp <= rbp) break;

        rbp = next_rbp;
        depth += 1;
    }

    if (depth == 0) {
        serial.printf(messages.NO_STACK_FRAMES, .{});
    }

    serial.printf("\n", .{});
}

pub fn render_raw_stack(rsp: u64, count: usize) void {
    serial.printf(messages.RAW_STACK, .{rsp});

    const stack_ptr: [*]const u64 = @ptrFromInt(rsp);

    for (0..count) |i| {
        serial.printf("  [%x]: %x\n", .{ rsp + i * 8, stack_ptr[i] });
    }

    serial.printf("\n", .{});
}
