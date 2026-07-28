//! Keyboard IRQ Handler

const io = @import("asm").io;

const constants = @import("mirai").drivers.constants;
const interrupts = @import("mirai").interrupts;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").drivers.strings;

const messages = strings.keyboard.messages;
const ports = constants.keyboard.ports;

var last_scancode: u8 = 0;

pub fn handler(_: u8) void {
    const scancode = io.port.readByte(ports.DATA);
    last_scancode = scancode;
    serial.write.printf(messages.SCANCODE, .{scancode});
}

pub fn register() void {
    interrupts.handlers.hardware.registerHandler(ports.IRQ, &handler);
    interrupts.pic.mask.enableIRQ(ports.IRQ);
}

pub fn getLastScancode() u8 {
    return last_scancode;
}
