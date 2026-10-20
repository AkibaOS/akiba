//! Hikari EFI Simple Text Input Protocol

const constants = @import("hikari").efi.constants;
const types = @import("hikari").efi.types;

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
