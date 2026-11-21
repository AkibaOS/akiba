//! Scoped Boot Disk Geometry And Device Slot

const Slot = @import("mirai").device.types.ahci.slot.Slot;

pub const Disk = struct {
    Slot: Slot,
    Sectors: u64,
};
