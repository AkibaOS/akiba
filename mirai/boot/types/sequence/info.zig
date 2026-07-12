//! Boot Information Type

const pmm_types = @import("../../../pmm/types/types.zig");
const MemoryRegion = pmm_types.MemoryRegion;

pub const BootInfo = struct {
    memory_map: [*]const MemoryRegion,
    memory_map_count: u64,
    framebuffer_address: u64,
    framebuffer_width: u32,
    framebuffer_height: u32,
    framebuffer_pitch: u32,
    framebuffer_bpp: u8,
    kernel_physical_base: u64,
    kernel_physical_end: u64,
    kernel_virtual_base: u64,
    pml4_physical: u64,
    rsdp_address: u64,
    boot_stack_top: u64,

    pub fn total_memory(self: BootInfo) u64 {
        var total: u64 = 0;
        var index: u64 = 0;
        while (index < self.memory_map_count) : (index += 1) {
            total += self.memory_map[index].length;
        }
        return total;
    }

    pub fn usable_memory(self: BootInfo) u64 {
        var usable: u64 = 0;
        var index: u64 = 0;
        while (index < self.memory_map_count) : (index += 1) {
            if (self.memory_map[index].is_usable()) {
                usable += self.memory_map[index].length;
            }
        }
        return usable;
    }

    pub fn kernel_size(self: BootInfo) u64 {
        return self.kernel_physical_end - self.kernel_physical_base;
    }
};
