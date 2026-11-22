//! Per Instance AHCI Storage Backing

const Handoff = @import("mirai").bootstrap.types.storage.handoff.Handoff;
const Location = @import("shared").ahci.types.discover.selection.Location;
const Volume = @import("shared").boot.types.volume.Volume;

pub const Disk = struct {
    ID: u64,
    Location: Location,
    Boot: ?Handoff = null,
    Handle: u64 = 0,
    PulseID: u64 = 0,
    Volume: ?Volume = null,
    LastSector: ?u64 = null,
    Verified: bool = false,
    Confirmed: bool = false,
    AfsID: ?u64 = null,
};
