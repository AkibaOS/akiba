//! Keyboard IRQ Handler

const cancellation = if (options.GUEST_CHECKS) @import("tests").guest.support.cancellation else null;
const constants = @import("mirai").drivers.constants;
const instances = @import("mirai").device.instance.registry;
const interrupts = @import("mirai").interrupts;
const io = @import("asm").io;
const options = @import("options");
const presentation = @import("mirai").device.strings.instance;
const serial = @import("mirai").drivers.serial;
const stream = @import("mirai").device.keyboard.stream;
const strings = @import("mirai").drivers.strings;

const messages = strings.keyboard.messages;
const ports = constants.keyboard.ports;

var last_scancode: u8 = 0;

pub fn handler(_: u8) void {
    const scancode = io.port.readByte(ports.DATA);
    last_scancode = scancode;
    stream.push(scancode);
    if (options.GUEST_CHECKS) cancellation.observe(scancode);
    serial.write.printf(messages.SCANCODE, .{scancode});
}

pub fn register() void {
    interrupts.handlers.hardware.registerHandler(ports.IRQ, &handler);
    stream.attach(instances.register(.Keyboard, ports.IRQ) orelse @panic(presentation.REGISTRY_FULL));
    interrupts.pic.mask.enableIRQ(ports.IRQ);
}

pub fn getLastScancode() u8 {
    return last_scancode;
}
