//! CPU Phase

const constants = @import("mirai").boot.constants;
const gdt = @import("mirai").boot.gdt;
const print = @import("mirai").boot.sequence.print;
const strings = @import("mirai").boot.strings;
const tss = @import("mirai").boot.tss;

const messages = strings.sequence.messages;
const status = strings.sequence.status;

pub fn execute() bool {
    print.phase(status.PROCESSOR);

    print.log(messages.TSS_SETUP, .{});
    tss.setup.initializeBoot();

    print.log(messages.GDT_SETUP, .{});
    const tss_address = tss.state.getBootTSSAddress();
    gdt.setup.initialize(tss_address, constants.tss.limits.TSS_SIZE);

    return true;
}
