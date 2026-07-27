//! Framebuffer Draw Operations

const state = @import("state.zig");

pub fn fill(color: u32) void {
    if (!state.isInitialized()) {
        return;
    }

    const base: [*]u32 = @ptrFromInt(state.getBase());
    const width = state.getWidth();
    const height = state.getHeight();
    const stride = state.getStride();

    var row: u32 = 0;
    while (row < height) : (row += 1) {
        var column: u32 = 0;
        while (column < width) : (column += 1) {
            base[row * stride + column] = color;
        }
    }
}

pub fn drawPixel(x: u32, y: u32, color: u32) void {
    if (!state.isInitialized()) {
        return;
    }

    if (x >= state.getWidth() or y >= state.getHeight()) {
        return;
    }

    const base: [*]u32 = @ptrFromInt(state.getBase());
    base[y * state.getStride() + x] = color;
}

pub fn fillRect(x: u32, y: u32, rect_width: u32, rect_height: u32, color: u32) void {
    if (!state.isInitialized()) {
        return;
    }

    const base: [*]u32 = @ptrFromInt(state.getBase());
    const width = state.getWidth();
    const height = state.getHeight();
    const stride = state.getStride();

    var row: u32 = y;
    while (row < y + rect_height and row < height) : (row += 1) {
        var column: u32 = x;
        while (column < x + rect_width and column < width) : (column += 1) {
            base[row * stride + column] = color;
        }
    }
}
