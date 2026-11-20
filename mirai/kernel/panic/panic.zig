//! Report And Halt On A Kernel Panic

const crimson = @import("mirai").crimson;
const halt = @import("asm").cpu.halt;
const serial = @import("mirai").drivers.serial.write;

pub fn handle(message: []const u8, _: ?usize) noreturn {
    serial.printf(crimson.strings.messages.KERNEL_PANIC, .{message});
    halt.haltLoop();
}
