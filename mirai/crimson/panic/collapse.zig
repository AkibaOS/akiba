//! Report A Fatal Collapse

const constants = @import("mirai").crimson.constants;
const gather = @import("mirai").crimson.panic.gather;
const halt = @import("mirai").crimson.panic.halt;
const interrupt = @import("asm").interrupts;
const render = @import("mirai").crimson.render;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const messages = strings.messages;
const Context = types.context.Context;
const Exception = types.exception.Exception;

var collapse_in_progress: bool = false;

pub fn collapse(message: []const u8, exception: ?*const Exception) noreturn {
    interrupt.flags.disableInterrupts();
    if (collapse_in_progress) {
        serial.write.printf(messages.DOUBLE_COLLAPSE, .{});
        halt.haltCurrent();
    }
    collapse_in_progress = true;

    render.banner.render();
    render.banner.renderMessage(message[0..@min(message.len, constants.limits.MAX_REASON_BYTES)]);
    if (exception) |found| {
        render.exception.render(found);
        render.context.render(found.Context);
    } else {
        var context: Context = undefined;
        gather.captureCurrentContext(&context);
        render.context.render(&context);
    }
    render.banner.renderHalt();
    halt.haltCurrent();
}
