//! Trigger Collapse (Panic)

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const render = @import("../render/render.zig");
const gather = @import("gather.zig");
const halt_module = @import("halt.zig");
const messages = @import("../strings/strings.zig").messages;

const Exception = types.Exception;
const Context = types.Context;

var collapse_in_progress: bool = false;
var collapse_message: [256]u8 = undefined;
var collapse_message_len: usize = 0;

pub fn collapse(message: []const u8, exception: ?*const Exception) noreturn {
    if (collapse_in_progress) {
        serial.printf(messages.double_collapse, .{});
        halt_module.halt_all();
    }

    collapse_in_progress = true;

    set_message(message);

    render.render_collapse_banner();
    render.render_message(get_message());

    if (exception) |exc| {
        render.render_exception(exc);
        render.render_context(exc.context);
    } else {
        var context: Context = undefined;
        gather.capture_current_context(&context);
        render.render_context(&context);
    }

    render.render_halt_message();

    halt_module.halt_all();
}

pub fn collapse_with_context(message: []const u8, context: *const Context) noreturn {
    if (collapse_in_progress) {
        serial.printf(messages.double_collapse, .{});
        halt_module.halt_all();
    }

    collapse_in_progress = true;

    set_message(message);

    render.render_collapse_banner();
    render.render_message(get_message());
    render.render_context(context);
    render.render_halt_message();

    halt_module.halt_all();
}

fn set_message(message: []const u8) void {
    const len = @min(message.len, 255);
    for (message[0..len], 0..) |c, i| {
        collapse_message[i] = c;
    }
    collapse_message[len] = 0;
    collapse_message_len = len;
}

fn get_message() []const u8 {
    return collapse_message[0..collapse_message_len];
}

pub fn is_collapsing() bool {
    return collapse_in_progress;
}
