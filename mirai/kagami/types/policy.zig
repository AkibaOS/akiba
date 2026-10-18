//! Owned Kernel Mapping Policy Type

const image = @import("mirai").boot.types.image;

pub const Policy = struct {
    Image: image.Manifest = .{},
    PhysmapBase: u64 = 0,
    PhysmapSize: u64 = 0,
    PhysicalLimit: u64 = 0,
    FramebufferStart: u64 = 0,
    FramebufferEnd: u64 = 0,
    BootStackBase: u64 = 0,
    BootStackTop: u64 = 0,
};
