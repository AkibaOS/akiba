//! Memory Region Type

const common = @import("common");

const sizes = common.constants.memory.sizes;

pub const RegionType = enum(u32) {
    Available = 1,
    Reserved = 2,
    ACPIReclaimable = 3,
    ACPINVS = 4,
    Bad = 5,
    _,
};

pub const MemoryRegion = struct {
    BaseAddress: u64,
    Length: u64,
    RegionType: RegionType,

    pub fn endAddress(self: MemoryRegion) u64 {
        return self.BaseAddress + self.Length;
    }

    pub fn pageCount(self: MemoryRegion) u64 {
        return self.Length / sizes.PAGE_SIZE;
    }

    pub fn isUsable(self: MemoryRegion) bool {
        return self.RegionType == .Available;
    }
};
