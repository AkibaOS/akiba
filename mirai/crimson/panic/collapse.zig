//! Trigger Collapse (Panic)

const constants = @import("mirai").crimson.constants;
const gather = @import("mirai").crimson.panic.gather;
const halt = @import("mirai").crimson.panic.halt;
const render = @import("mirai").crimson.render;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const text = @import("utils").text;

const limits = constants.limits;
const messages = strings.messages;

const Context = types.context.Context;
const Exception = types.exception.Exception;

var collapse_in_progress: bool = false;
var collapse_message: [limits.MESSAGE_CAPACITY]u8 = undefined;
var collapse_message_length: usize = 0;

pub fn collapse(message: []const u8, exception: ?*const Exception) noreturn {
    if (collapse_in_progress) {
        serial.write.printf(messages.DOUBLE_COLLAPSE, .{});
        halt.haltAll();
    }

    collapse_in_progress = true;

    setMessage(message);

    render.banner.render();
    render.banner.renderMessage(getMessage());

    if (exception) |found| {
        render.exception.render(found);
        render.context.render(found.Context);
    } else {
        var context: Context = undefined;
        gather.captureCurrentContext(&context);
        render.context.render(&context);
    }

    render.banner.renderHalt();

    halt.haltAll();
}

pub fn collapseWithContext(message: []const u8, context: *const Context) noreturn {
    if (collapse_in_progress) {
        serial.write.printf(messages.DOUBLE_COLLAPSE, .{});
        halt.haltAll();
    }

    collapse_in_progress = true;

    setMessage(message);

    render.banner.render();
    render.banner.renderMessage(getMessage());
    render.context.render(context);
    render.banner.renderHalt();

    halt.haltAll();
}

fn setMessage(message: []const u8) void {
    const length = text.ascii.copyBounded(collapse_message[0 .. limits.MESSAGE_CAPACITY - 1], message);
    collapse_message[length] = 0;
    collapse_message_length = length;
}

fn getMessage() []const u8 {
    return collapse_message[0..collapse_message_length];
}

pub fn isCollapsing() bool {
    return collapse_in_progress;
}
