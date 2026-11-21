//! Private AHCI Device Invocation Contract

const Volume = @import("shared").boot.types.volume.Volume;

pub const Operation = enum(u64) { Describe, Identify, Read, Confirm };

pub const Description = extern struct {
    PulseID: u64,
    Volume: Volume,
};
