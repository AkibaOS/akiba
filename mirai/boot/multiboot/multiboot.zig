//! Multiboot2 protocol

pub const types = @import("types.zig");
pub const memory = @import("memory.zig");
pub const framebuffer = @import("framebuffer.zig");

pub const MemoryEntry = types.MemoryEntry;
pub const FramebufferInfo = types.FramebufferInfo;

pub const parse_memory_map = memory.parse;
pub const parse_framebuffer = framebuffer.parse;
pub const init_framebuffer = framebuffer.set;
pub const get_framebuffer = framebuffer.get;
