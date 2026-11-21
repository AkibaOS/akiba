//! Scoped Read Only Bootstrap Disk Callbacks

const Disk = @import("mirai").bootstrap.types.storage.disk.Disk;
const Volume = @import("shared").boot.types.volume.Volume;

pub const Match = *const fn (*anyopaque, *Disk) anyerror!bool;
pub const Read = *const fn (*anyopaque, *Disk) anyerror!void;

pub const Context = struct {
    Argument: *anyopaque,
    Use: Match,
};

pub const Lease = struct {
    Expected: Volume,
    Context: *anyopaque,
    Consume: Read,
};
