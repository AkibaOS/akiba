//! Hikari EFI Simple Unit System Protocol

const constants = @import("hikari").efi.constants;
const types = @import("hikari").efi.types;
const unit = @import("hikari").efi.protocols.unit;

const convention = constants.convention.CALLING_CONVENTION;

pub const SimpleUnitSystemProtocol = extern struct {
    Revision: u64,

    OpenVolume: *const fn (
        self: *SimpleUnitSystemProtocol,
        root: **unit.UnitProtocol,
    ) callconv(convention) types.base.Status,
};
