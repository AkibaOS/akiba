//! Interrupts Phase

const interrupts = @import("../../../interrupts/interrupts.zig");
const pit = @import("../../../drivers/pit/pit.zig");
const keyboard = @import("../../../drivers/keyboard/keyboard.zig");
const serial = @import("../../../drivers/serial/serial.zig");
const messages = @import("../strings/strings.zig").messages;

pub fn execute() bool {
    serial.printf(messages.idt_setup, .{});
    interrupts.initialize();

    serial.printf(messages.timer_setup, .{});
    pit.initialize();
    pit.register();

    serial.printf(messages.keyboard_setup, .{});
    keyboard.register();

    interrupts.enable();
    serial.printf(messages.interrupts_enabled, .{});

    return true;
}
