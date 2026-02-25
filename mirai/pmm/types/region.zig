//! Memory Region Type

pub const MemoryRegion = struct {
    base_address: u64,
    length: u64,
    region_type: RegionType,

    pub const RegionType = enum(u32) {
        available = 1,
        reserved = 2,
        acpi_reclaimable = 3,
        acpi_nvs = 4,
        bad = 5,
        _,
    };

    pub fn end_address(self: MemoryRegion) u64 {
        return self.base_address + self.length;
    }

    pub fn page_count(self: MemoryRegion) u64 {
        return self.length / 4096;
    }

    pub fn is_usable(self: MemoryRegion) bool {
        return self.region_type == .available;
    }
};
