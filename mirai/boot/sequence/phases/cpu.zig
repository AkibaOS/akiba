//! CPU Phase

const gdt = @import("../../gdt/gdt.zig");
const tss = @import("../../tss/tss.zig");
const tss_constants = @import("../../constants/tss/tss.zig");
const serial = @import("../../../drivers/serial/serial.zig");
const messages = @import("../../strings/sequence/sequence.zig").messages;

pub fn execute() bool {
    serial.printf(messages.TSS_SETUP, .{});
    tss.initialize_boot();

    serial.printf(messages.GDT_SETUP, .{});
    const tss_address = tss.get_boot_tss_address();
    gdt.initialize(tss_address, tss_constants.tss_size);

    return true;
}
