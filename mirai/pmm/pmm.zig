//! Physical Memory Manager

pub const constants = @import("constants/constants.zig");
pub const types = @import("types/types.zig");
pub const bitmap = @import("bitmap/bitmap.zig");
pub const allocate = @import("allocate/allocate.zig");
pub const free = @import("free/free.zig");
pub const init = @import("init/init.zig");
pub const state = @import("state.zig");

pub const initialize = init.initialize_from_memory_map;
pub const is_initialized = state.is_initialized;
pub const get_state = state.get_state;

pub const allocate_page = allocate.allocate_page;
pub const allocate_page_zeroed = allocate.allocate_page_zeroed;
pub const allocate_contiguous = allocate.allocate_contiguous;
pub const allocate_contiguous_zeroed = allocate.allocate_contiguous_zeroed;
pub const allocate_aligned = allocate.allocate_aligned;

pub const free_page = free.free_page;
pub const free_range = free.free_range;

pub const Statistics = types.Statistics;
pub const PhysicalPage = types.PhysicalPage;
pub const MemoryRegion = types.MemoryRegion;

pub fn get_statistics() Statistics {
    const pmm_state = state.get_state();
    return Statistics{
        .total_pages = pmm_state.total_pages,
        .free_pages = pmm_state.free_pages,
        .used_pages = pmm_state.used_pages,
        .reserved_pages = pmm_state.reserved_pages,
        .wired_pages = pmm_state.wired_pages,
    };
}
