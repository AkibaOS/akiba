//! Framebuffer Initialization

const state = @import("state.zig");

pub fn initialize(base: u64, width: u32, height: u32, stride: u32) bool {
    if (base == 0 or width == 0 or height == 0) {
        return false;
    }

    state.set(base, width, height, stride);
    return true;
}
