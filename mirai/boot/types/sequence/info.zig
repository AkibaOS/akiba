//! Boot Information Type

const pmm = @import("../../../pmm/pmm.zig");

const MemoryRegion = pmm.types.region.MemoryRegion;

pub const BootInfo = struct {
    MemoryMap: [*]const MemoryRegion,
    MemoryMapCount: u64,
    FramebufferAddress: u64,
    FramebufferWidth: u32,
    FramebufferHeight: u32,
    FramebufferPitch: u32,
    FramebufferBPP: u8,
    KernelPhysicalBase: u64,
    KernelPhysicalEnd: u64,
    KernelVirtualBase: u64,
    PML4Physical: u64,
    RSDPAddress: u64,
    BootStackTop: u64,

    pub fn totalMemory(self: BootInfo) u64 {
        var total: u64 = 0;
        var index: u64 = 0;
        while (index < self.MemoryMapCount) : (index += 1) {
            total += self.MemoryMap[index].Length;
        }
        return total;
    }

    pub fn usableMemory(self: BootInfo) u64 {
        var usable: u64 = 0;
        var index: u64 = 0;
        while (index < self.MemoryMapCount) : (index += 1) {
            if (self.MemoryMap[index].isUsable()) {
                usable += self.MemoryMap[index].Length;
            }
        }
        return usable;
    }

    pub fn kernelSize(self: BootInfo) u64 {
        return self.KernelPhysicalEnd - self.KernelPhysicalBase;
    }
};
