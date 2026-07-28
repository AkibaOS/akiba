//! Hardware IRQ Stubs (Vectors 32-47)

const common = @import("common");

const stubgen = @import("asm").interrupts.stubs;

const frame = @import("mirai").interrupts.handlers.common;
const pic = @import("mirai").interrupts.pic;

const vectors = common.constants.interrupts.vectors;

const InterruptFrame = frame.InterruptFrame;

var irq_handlers: [vectors.IRQ_COUNT]?*const fn (u8) void = [_]?*const fn (u8) void{null} ** vectors.IRQ_COUNT;

pub fn registerHandler(irq: u4, handler: *const fn (u8) void) void {
    irq_handlers[irq] = handler;
}

pub fn unregisterHandler(irq: u4) void {
    irq_handlers[irq] = null;
}

export fn irq_dispatch(interrupt_frame: *InterruptFrame) void {
    const vector: u8 = @truncate(interrupt_frame.Vector);
    const irq: u8 = vector - vectors.VECTOR_OFFSET;

    if (irq < vectors.IRQ_COUNT) {
        if (irq_handlers[irq]) |handler| {
            handler(irq);
        }
        pic.eoi.send(@truncate(irq));
    }
}

pub const stubs = blk: {
    var array: [vectors.IRQ_COUNT]*const fn () callconv(.naked) void = undefined;
    for (0..vectors.IRQ_COUNT) |irq| {
        array[irq] = &stubgen.makeIRQHandler(@intCast(irq));
    }
    break :blk array;
};
