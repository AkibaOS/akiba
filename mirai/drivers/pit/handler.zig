//! PIT IRQ Handler

const constants = @import("../constants/pit/pit.zig");
const pic = @import("../../interrupts/pic/pic.zig");
const idt = @import("../../interrupts/idt.zig");

var ticks: u64 = 0;
var tick_callback: ?*const fn () void = null;

pub fn handler(_: u8) void {
    ticks += 1;

    if (tick_callback) |callback| {
        callback();
    }
}

pub fn register() void {
    idt.register_irq(constants.irq, &handler);
    pic.enable_irq(constants.irq);
}

pub fn set_callback(callback: *const fn () void) void {
    tick_callback = callback;
}

pub fn clear_callback() void {
    tick_callback = null;
}

pub fn get_ticks() u64 {
    return ticks;
}
