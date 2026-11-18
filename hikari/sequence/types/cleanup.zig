//! Resources Owned By A Boot Attempt Before Transfer

const efi = @import("hikari").efi;
const handoff = @import("hikari").sequence.types.handoff;
const paging = @import("hikari").paging;

pub const Claims = struct {
    Paging: paging.types.setup.PageTableSetup,
    Handoff: ?handoff.Handoff = null,
    Image: efi.types.pages.Claim = .{},
    Source: ?[*]align(8) u8 = null,
};
