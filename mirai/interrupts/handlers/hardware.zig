//! Hardware IRQ Stubs (Vectors 32-47)

const common = @import("common.zig");
const InterruptFrame = common.InterruptFrame;
const asm_stubs = @import("../../asm/interrupts/stubs.zig");

var irq_handlers: [16]?*const fn (u8) void = [_]?*const fn (u8) void{null} ** 16;

pub fn register_handler(irq: u4, handler: *const fn (u8) void) void {
    irq_handlers[irq] = handler;
}

pub fn unregister_handler(irq: u4) void {
    irq_handlers[irq] = null;
}

fn make_irq_handler(comptime irq: u8) fn () callconv(.Naked) void {
    return struct {
        fn handler() callconv(.Naked) void {
            asm volatile ("push $0");
            asm volatile ("push %[v]"
                :
                : [v] "i" (irq + 32),
            );
            asm volatile (asm_stubs.push_all ++
                    \\mov %%rsp, %%rdi
                    \\call irq_dispatch
                ++ asm_stubs.pop_all ++ asm_stubs.iret_cleanup);
        }
    }.handler;
}

export fn irq_dispatch(frame: *InterruptFrame) void {
    const vector: u8 = @truncate(frame.vector);
    const irq = vector - 32;

    if (irq < 16) {
        if (irq_handlers[irq]) |handler| {
            handler(irq);
        }
    }
}

pub const irq_0 = make_irq_handler(0);
pub const irq_1 = make_irq_handler(1);
pub const irq_2 = make_irq_handler(2);
pub const irq_3 = make_irq_handler(3);
pub const irq_4 = make_irq_handler(4);
pub const irq_5 = make_irq_handler(5);
pub const irq_6 = make_irq_handler(6);
pub const irq_7 = make_irq_handler(7);
pub const irq_8 = make_irq_handler(8);
pub const irq_9 = make_irq_handler(9);
pub const irq_10 = make_irq_handler(10);
pub const irq_11 = make_irq_handler(11);
pub const irq_12 = make_irq_handler(12);
pub const irq_13 = make_irq_handler(13);
pub const irq_14 = make_irq_handler(14);
pub const irq_15 = make_irq_handler(15);

pub const stubs = [16]*const fn () callconv(.Naked) void{
    &irq_0,  &irq_1,  &irq_2,  &irq_3,
    &irq_4,  &irq_5,  &irq_6,  &irq_7,
    &irq_8,  &irq_9,  &irq_10, &irq_11,
    &irq_12, &irq_13, &irq_14, &irq_15,
};
