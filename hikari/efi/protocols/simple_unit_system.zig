//! Hikari EFI Simple Unit System Protocol

const types = @import("../types/types.zig");
const unit = @import("unit.zig");

pub const SimpleUnitSystemProtocol = extern struct {
    revision: u64,

    open_volume: *const fn (
        self: *SimpleUnitSystemProtocol,
        root: **unit.UnitProtocol,
    ) callconv(.C) types.Status,
};
