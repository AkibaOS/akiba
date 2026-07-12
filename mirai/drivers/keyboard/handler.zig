//! Keyboard IRQ Handler

const asm_io = @import("../../asm/io/io.zig");
const idt = @import("../../interrupts/idt.zig");
const pic = @import("../../interrupts/pic/pic.zig");
const serial = @import("../serial/serial.zig");
const constants = @import("constants/constants.zig");
const messages = @import("strings/strings.zig").messages;

var last_scancode: u8 = 0;

pub fn handler(_: u8) void {
    const scancode = asm_io.read_byte(constants.data);
    last_scancode = scancode;
    serial.printf(messages.scancode, .{scancode});
}

pub fn register() void {
    idt.register_irq(constants.irq, &handler);
    pic.enable_irq(constants.irq);
}

pub fn get_last_scancode() u8 {
    return last_scancode;
}
