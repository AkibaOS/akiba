//! CPU Phase

const constants = @import("mirai").boot.constants;
const gdt = @import("mirai").boot.gdt;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").boot.strings;
const tss = @import("mirai").boot.tss;

const messages = strings.sequence.messages;

pub fn execute() bool {
    serial.write.printf(messages.TSS_SETUP, .{});
    tss.setup.initializeBoot();

    serial.write.printf(messages.GDT_SETUP, .{});
    const tss_address = tss.state.getBootTSSAddress();
    gdt.setup.initialize(tss_address, constants.tss.limits.TSS_SIZE);

    return true;
}
