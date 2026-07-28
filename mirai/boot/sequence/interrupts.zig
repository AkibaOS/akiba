//! Interrupts Phase

const interrupts = @import("mirai").interrupts;
const keyboard = @import("mirai").drivers.keyboard;
const pit = @import("mirai").drivers.pit;
const print = @import("mirai").boot.sequence.print;
const strings = @import("mirai").boot.strings;

const messages = strings.sequence.messages;
const status = strings.sequence.status;

pub fn execute() bool {
    print.phase(status.SYSTEM_SERVICES);

    print.log(messages.IDT_SETUP, .{});
    interrupts.setup.initialize();

    print.log(messages.TIMER_SETUP, .{});
    pit.init.initDefault();
    pit.handler.register();

    print.log(messages.KEYBOARD_SETUP, .{});
    keyboard.handler.register();

    interrupts.setup.enable();
    print.log(messages.INTERRUPTS_ENABLED, .{});

    return true;
}
