//! CPU Phase

const constants = @import("../constants/constants.zig");
const gdt = @import("../gdt/gdt.zig");
const serial = @import("../../drivers/serial/serial.zig");
const strings = @import("../strings/strings.zig");
const tss = @import("../tss/tss.zig");

const messages = strings.sequence.messages;

pub fn execute() bool {
    serial.write.printf(messages.TSS_SETUP, .{});
    tss.setup.initializeBoot();

    serial.write.printf(messages.GDT_SETUP, .{});
    const tss_address = tss.state.getBootTSSAddress();
    gdt.setup.initialize(tss_address, constants.tss.limits.TSS_SIZE);

    return true;
}
