//! Render Stack Availability

const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const messages = strings.messages;

const Context = types.context.Context;

pub fn render(context: *const Context) void {
    _ = context;
    serial.write.printf(messages.STACK_TRACE_HEADER, .{});
    serial.write.printf(messages.STACK_TRACE_UNAVAILABLE, .{});
}

pub fn renderRawStack(rsp: u64, count: usize) void {
    _ = count;
    serial.write.printf(messages.RAW_STACK, .{rsp});
    serial.write.printf(messages.RAW_STACK_UNAVAILABLE, .{});
}
