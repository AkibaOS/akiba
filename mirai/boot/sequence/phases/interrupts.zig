//! Interrupts Phase

const interrupts = @import("../../../interrupts/interrupts.zig");
const pit = @import("../../../drivers/pit/pit.zig");
const keyboard = @import("../../../drivers/keyboard/keyboard.zig");
const serial = @import("../../../drivers/serial/serial.zig");
const messages = @import("../strings/strings.zig").messages;

pub fn execute() bool {
    serial.printf(messages.IDT_SETUP, .{});
    interrupts.initialize();

    serial.printf(messages.TIMER_SETUP, .{});
    pit.initialize();
    pit.register();

    serial.printf(messages.KEYBOARD_SETUP, .{});
    keyboard.register();

    interrupts.enable();
    serial.printf(messages.INTERRUPTS_ENABLED, .{});

    return true;
}
