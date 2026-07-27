//! PIT IRQ Handler

const constants = @import("../constants/constants.zig");
const interrupts = @import("../../interrupts/interrupts.zig");

const limits = constants.pit.limits;

var ticks: u64 = 0;
var tick_callback: ?*const fn () void = null;

pub fn handler(_: u8) void {
    ticks += 1;

    if (tick_callback) |callback| {
        callback();
    }
}

pub fn register() void {
    interrupts.handlers.hardware.registerHandler(limits.IRQ, &handler);
    interrupts.pic.mask.enableIRQ(limits.IRQ);
}

pub fn setCallback(callback: *const fn () void) void {
    tick_callback = callback;
}

pub fn clearCallback() void {
    tick_callback = null;
}

pub fn getTicks() u64 {
    return ticks;
}
