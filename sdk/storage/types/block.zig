//! Assigned Block Device Description And Read Fields

const Volume = @import("sdk").storage.types.volume.Volume;

pub const Description = extern struct {
    PulseID: u64,
    Volume: Volume,
};

pub const Read = extern struct {
    Sector: u64,
    Destination: u64,
};
