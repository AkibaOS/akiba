//! Physical Page Type

const address = @import("utils").address;

pub const PhysicalPage = struct {
    FrameNumber: u64,
    ReferenceCount: u32,
    Flags: PageFlags,

    pub const PageFlags = packed struct {
        Allocated: bool = false,
        Wired: bool = false,
        Reserved: bool = false,
        Kernel: bool = false,
        Padding: u28 = 0,
    };

    pub fn physicalAddress(self: PhysicalPage) u64 {
        return address.translate.pageToAddress(self.FrameNumber);
    }

    pub fn fromPhysicalAddress(physical_address: u64) PhysicalPage {
        return PhysicalPage{
            .FrameNumber = address.translate.addressToPage(physical_address),
            .ReferenceCount = 0,
            .Flags = .{},
        };
    }
};
