//! Memory Limits - Address space limits and validation helpers

const memory_const = @import("../constants/memory.zig");

// ============================================================================
// Address Space Limits
// ============================================================================

/// Kata space maximum (below higher-half)
pub const KATA_SPACE_MAX: u64 = memory_const.KATA_SPACE_END;

/// First valid kata space page (page 0 is always invalid for null pointer detection)
pub const KATA_SPACE_MIN: u64 = memory_const.KATA_SPACE_START;

/// Higher-half Mirai space start
pub const MIRAI_SPACE_START: u64 = memory_const.HIGHER_HALF_START;

// ============================================================================
// Validation Helpers
// ============================================================================

/// Check if a pointer is in valid kata space range
pub inline fn is_valid_kata_pointer(ptr: u64) bool {
    return ptr >= KATA_SPACE_MIN and ptr < KATA_SPACE_MAX;
}

/// Check if a virtual address is in kata space
pub inline fn is_kata_address(addr: u64) bool {
    return addr < KATA_SPACE_MAX;
}

/// Check if a virtual address is in Mirai space
pub inline fn is_mirai_address(addr: u64) bool {
    return addr >= MIRAI_SPACE_START;
}

/// Check if a memory range is entirely within kata space
pub inline fn is_kata_range(start: u64, size: u64) bool {
    if (start >= KATA_SPACE_MAX) return false;
    if (size == 0) return true;
    const end = start +% size;
    if (end < start) return false; // Overflow occurred
    return end <= KATA_SPACE_MAX;
}
