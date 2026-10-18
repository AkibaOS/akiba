//! CPU Phase

const early = @import("mirai").boot.early;
const print = @import("mirai").boot.sequence.print;
const strings = @import("mirai").boot.strings;

const messages = strings.sequence.messages;
const status = strings.sequence.status;

pub fn execute() bool {
    print.phase(status.PROCESSOR);

    print.log(messages.TSS_SETUP, .{});
    print.log(messages.GDT_SETUP, .{});
    if (!early.setup.isInitialized()) {
        print.log(messages.EARLY_STATE_UNAVAILABLE, .{});
        return false;
    }

    print.log(messages.EARLY_STATE_READY, .{});
    return true;
}
