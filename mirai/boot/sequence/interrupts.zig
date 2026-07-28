//! Interrupts Phase

const interrupts = @import("mirai").interrupts;
const keyboard = @import("mirai").drivers.keyboard;
const pit = @import("mirai").drivers.pit;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").boot.strings;

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
