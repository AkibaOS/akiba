//! Real EFI AFS Acquisition Ownership State

const efi = @import("hikari").efi;
const reader = @import("hikari").fs.types.afs.reader;

pub const State = struct {
    Real: *efi.types.services.boot.BootServices,
    Reader: ?reader.Reader = null,
    Allocations: usize = 0,
    Releases: usize = 0,
    LivePools: usize = 0,
    Broken: bool = false,
    CaptureSource: bool = false,
    Source: ?[*]align(8) u8 = null,
    SourceFreeCalls: usize = 0,
    RefuseSourceReleases: usize = 1,
};
