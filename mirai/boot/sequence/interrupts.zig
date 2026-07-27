//! Interrupts Phase

const interrupts = @import("../../interrupts/interrupts.zig");
const keyboard = @import("../../drivers/keyboard/keyboard.zig");
const pit = @import("../../drivers/pit/pit.zig");
const serial = @import("../../drivers/serial/serial.zig");
const strings = @import("../strings/strings.zig");

const messages = strings.sequence.messages;

pub fn execute() bool {
    serial.write.printf(messages.IDT_SETUP, .{});
    interrupts.setup.initialize();

    serial.write.printf(messages.TIMER_SETUP, .{});
    pit.init.initDefault();
    pit.handler.register();

    serial.write.printf(messages.KEYBOARD_SETUP, .{});
    keyboard.handler.register();

    interrupts.setup.enable();
    serial.write.printf(messages.INTERRUPTS_ENABLED, .{});

    return true;
}
