//! Resources Owned By A Boot Attempt Before Transfer

const efi = @import("hikari").efi;
const handoff = @import("hikari").sequence.types.handoff;
const paging = @import("hikari").paging;
const partition = @import("hikari").sequence.types.partition;
const reader = @import("hikari").fs.types.afs.reader;

pub const Claims = struct {
    Paging: paging.types.setup.PageTableSetup,
    Discovery: ?partition.Discovery = null,
    Reader: ?reader.Reader = null,
    Handoff: ?handoff.Handoff = null,
    Image: efi.types.pages.Claim = .{},
    Source: efi.types.buffer.PoolClaim = .{},
};
