//! Hikari EFI Simple Text Input Protocol

const types = @import("../types/types.zig");
const input = @import("../types/input.zig");

pub const SimpleTextInputProtocol = extern struct {
    reset: *const fn (
        self: *SimpleTextInputProtocol,
        extended_verification: bool,
    ) callconv(.C) types.Status,

    read_key_stroke: *const fn (
        self: *SimpleTextInputProtocol,
        key: *input.InputKey,
    ) callconv(.C) types.Status,

    wait_for_key: types.Event,
};
