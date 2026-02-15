//! Multiboot type definitions

pub const MemoryEntry = struct {
    base: u64,
    length: u64,
    entry_type: u32,
};

pub const FramebufferInfo = struct {
    addr: u64,
    pitch: u32,
    width: u32,
    height: u32,
    bpp: u8,
    framebuffer_type: u8,
};
