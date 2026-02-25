//! Physical Page Type

pub const PhysicalPage = struct {
    frame_number: u64,
    reference_count: u32,
    flags: PageFlags,

    pub const PageFlags = packed struct {
        allocated: bool = false,
        wired: bool = false,
        reserved: bool = false,
        kernel: bool = false,
        padding: u28 = 0,
    };

    pub fn physical_address(self: PhysicalPage) u64 {
        return self.frame_number << 12;
    }

    pub fn from_physical_address(address: u64) PhysicalPage {
        return PhysicalPage{
            .frame_number = address >> 12,
            .reference_count = 0,
            .flags = .{},
        };
    }
};
