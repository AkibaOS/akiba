//! Hikari EFI Simple Unit System Protocol

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");
const unit = @import("unit.zig");

const convention = constants.convention.CALLING_CONVENTION;

pub const SimpleUnitSystemProtocol = extern struct {
    Revision: u64,

    OpenVolume: *const fn (
        self: *SimpleUnitSystemProtocol,
        root: **unit.UnitProtocol,
    ) callconv(convention) types.base.Status,
};
