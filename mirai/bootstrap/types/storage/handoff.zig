//! Detached Boot Disk Identity Bound To Pulse

const Location = @import("shared").ahci.types.discover.selection.Location;
const Volume = @import("shared").boot.types.volume.Volume;

pub const Handoff = struct {
    PulseID: u64,
    Location: Location,
    Volume: Volume,
};
