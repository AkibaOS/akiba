//! IRQ handlers

const pic = @import("pic.zig");
const sensei = @import("../kata/sensei/sensei.zig");

export fn timer_handler() void {
    pic.send_eoi_master();
    sensei.on_tick();
}
