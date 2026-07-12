//! Hikari EFI Simple Text Input Protocol

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const convention = constants.convention.CALLING_CONVENTION;

pub const SimpleTextInputProtocol = extern struct {
    Reset: *const fn (
        self: *SimpleTextInputProtocol,
        extended_verification: bool,
    ) callconv(convention) types.base.Status,

    ReadKeyStroke: *const fn (
        self: *SimpleTextInputProtocol,
        key: *types.input.InputKey,
    ) callconv(convention) types.base.Status,

    WaitForKey: types.base.Event,
};
