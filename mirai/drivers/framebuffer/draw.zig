//! Framebuffer Draw Operations

const state = @import("state.zig");

pub fn fill(color: u32) void {
    if (!state.is_initialized()) {
        return;
    }

    const base: [*]u32 = @ptrFromInt(state.get_base());
    const width = state.get_width();
    const height = state.get_height();
    const stride = state.get_stride();

    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            base[y * stride + x] = color;
        }
    }
}

pub fn draw_pixel(x: u32, y: u32, color: u32) void {
    if (!state.is_initialized()) {
        return;
    }

    if (x >= state.get_width() or y >= state.get_height()) {
        return;
    }

    const base: [*]u32 = @ptrFromInt(state.get_base());
    base[y * state.get_stride() + x] = color;
}

pub fn fill_rect(x: u32, y: u32, rect_width: u32, rect_height: u32, color: u32) void {
    if (!state.is_initialized()) {
        return;
    }

    const base: [*]u32 = @ptrFromInt(state.get_base());
    const width = state.get_width();
    const height = state.get_height();
    const stride = state.get_stride();

    var row: u32 = y;
    while (row < y + rect_height and row < height) : (row += 1) {
        var column: u32 = x;
        while (column < x + rect_width and column < width) : (column += 1) {
            base[row * stride + column] = color;
        }
    }
}
