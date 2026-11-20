//! Memory And Address Information Carried Through Early Boot

const pmm = @import("mirai").pmm;
const retirement = @import("mirai").boot.types.retirement.footprint;

const MemoryRegion = pmm.types.region.MemoryRegion;

pub const BootInfo = struct {
    MemoryMap: []const MemoryRegion,
    Retirement: ?retirement.Footprint,
    FramebufferAddress: u64,
    FramebufferPhysicalAddress: u64,
    FramebufferSize: u64,
    KernelPhysicalBase: u64,
    KernelPhysicalEnd: u64,
    KernelVirtualBase: u64,
    PML4Physical: u64,
    LoaderPML4Physical: u64,
    PhysmapBase: u64,
    PhysmapSize: u64,
    BootStackTop: u64,
    BootStackSize: u64,
};
