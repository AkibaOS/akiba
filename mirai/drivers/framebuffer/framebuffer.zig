//! Framebuffer Driver

pub const init = @import("init.zig");
pub const draw = @import("draw.zig");
pub const state = @import("state.zig");

pub const initialize = init.initialize;
pub const fill = draw.fill;
pub const draw_pixel = draw.draw_pixel;
pub const fill_rect = draw.fill_rect;
pub const is_initialized = state.is_initialized;
