//! Actions Bound To A Live Diagnostic Epoch

const constants = @import("tests").phase.constants.action;

pub const Frame = [constants.FRAME_BYTES]u8;
pub const Mode = enum { Closed, Testing, Menu };
pub const Action = enum(u8) {
    Boot = 1,
    Shutdown = 2,
    Timeout = 3,
    Cancel = 4,
};
