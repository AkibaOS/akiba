//! IDT Setup

const common = @import("common");

const interrupt = @import("asm").interrupts;

const boot = @import("../../boot/boot.zig");
const handlers = @import("../handlers/handlers.zig");
const load = @import("../load/load.zig");
const pic = @import("../pic/pic.zig");
const table = @import("../table/table.zig");

const vectors = common.constants.interrupts.vectors;

pub fn initialize() void {
    pic.init.remap();
    pic.mask.maskAll();

    const selector = boot.constants.gdt.selectors.KERNEL_CODE_SELECTOR;

    for (0..vectors.EXCEPTION_COUNT) |index| {
        const vector: u8 = @truncate(index);
        const handler_address = @intFromPtr(handlers.exceptions.stubs[index]);
        table.install.setInterrupt(vector, handler_address, selector);
    }

    for (0..vectors.IRQ_COUNT) |index| {
        const vector: u8 = @as(u8, @truncate(index)) + vectors.VECTOR_OFFSET;
        const handler_address = @intFromPtr(handlers.hardware.stubs[index]);
        table.install.setInterrupt(vector, handler_address, selector);
    }

    load.lidt.load();
}

pub fn enable() void {
    interrupt.flags.enableInterrupts();
}

pub fn disable() void {
    interrupt.flags.disableInterrupts();
}
