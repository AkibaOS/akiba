//! Render Stack Trace

const constants = @import("../constants/constants.zig");
const serial = @import("../../drivers/serial/serial.zig");
const strings = @import("../strings/strings.zig");
const types = @import("../types/types.zig");

const limits = constants.limits;
const messages = strings.messages;

const Context = types.context.Context;

pub fn render(context: *const Context) void {
    serial.write.printf(messages.STACK_TRACE_HEADER, .{});

    var rbp = context.RBP;
    var depth: usize = 0;

    while (rbp != 0 and depth < limits.RENDER_MAX_STACK_DEPTH) {
        const frame_pointer: [*]const u64 = @ptrFromInt(rbp);

        const return_address = frame_pointer[1];
        if (return_address == 0) break;

        serial.write.printf("  [%d] %x\n", .{ depth, return_address });

        const next_rbp = frame_pointer[0];
        if (next_rbp <= rbp) break;

        rbp = next_rbp;
        depth += 1;
    }

    if (depth == 0) {
        serial.write.printf(messages.NO_STACK_FRAMES, .{});
    }

    serial.write.printf("\n", .{});
}

pub fn renderRawStack(rsp: u64, count: usize) void {
    serial.write.printf(messages.RAW_STACK, .{rsp});

    const stack_pointer: [*]const u64 = @ptrFromInt(rsp);

    for (0..count) |index| {
        serial.write.printf("  [%x]: %x\n", .{ rsp + index * @sizeOf(u64), stack_pointer[index] });
    }

    serial.write.printf("\n", .{});
}
