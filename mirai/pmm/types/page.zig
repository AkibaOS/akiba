//! Physical Page Type

const common = @import("common");

const sizes = common.constants.memory.sizes;

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
        return self.FrameNumber << sizes.PAGE_SHIFT;
    }

    pub fn fromPhysicalAddress(address: u64) PhysicalPage {
        return PhysicalPage{
            .FrameNumber = address >> sizes.PAGE_SHIFT,
            .ReferenceCount = 0,
            .Flags = .{},
        };
    }
};
