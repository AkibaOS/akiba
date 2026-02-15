//! Memory limits

const memory_const = @import("../constants/memory.zig");

pub const KATA_SPACE_MAX: u64 = memory_const.KATA_SPACE_END;
pub const KATA_SPACE_MIN: u64 = memory_const.KATA_SPACE_START;
pub const MIRAI_SPACE_START: u64 = memory_const.HIGHER_HALF_START;

pub inline fn is_valid_kata_pointer(ptr: u64) bool {
    return ptr >= KATA_SPACE_MIN and ptr < KATA_SPACE_MAX;
}

pub inline fn is_kata_address(addr: u64) bool {
    return addr < KATA_SPACE_MAX;
}

pub inline fn is_mirai_address(addr: u64) bool {
    return addr >= MIRAI_SPACE_START;
}

pub inline fn is_kata_range(start: u64, size: u64) bool {
    if (start >= KATA_SPACE_MAX) return false;
    if (size == 0) return true;
    const end = start +% size;
    if (end < start) return false;
    return end <= KATA_SPACE_MAX;
}
