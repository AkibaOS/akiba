//! Multiboot2 boot protocol parser

const serial = @import("../drivers/serial.zig");

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

const MAX_MEMORY_ENTRIES = 32;
var memory_entries: [MAX_MEMORY_ENTRIES]MemoryEntry = undefined;

var saved_framebuffer: ?FramebufferInfo = null;

pub fn init_framebuffer(fb: FramebufferInfo) void {
    saved_framebuffer = fb;
}

pub fn get_framebuffer() ?FramebufferInfo {
    return saved_framebuffer;
}

pub fn parse_memory_map(addr: u64) []MemoryEntry {
    serial.print("\n=== Multiboot2 Memory Map ===\n");

    const total_size = @as(*u32, @ptrFromInt(addr)).*;
    var offset: u64 = 8;
    var mem_count: usize = 0;

    while (offset < total_size) {
        const tag_addr = addr + offset;
        const tag_type = @as(*u32, @ptrFromInt(tag_addr)).*;
        const tag_size = @as(*u32, @ptrFromInt(tag_addr + 4)).*;

        if (tag_type == 0) break;

        // Memory map tag (type 6)
        if (tag_type == 6) {
            const entry_size = @as(*u32, @ptrFromInt(tag_addr + 8)).*;
            const entry_count = (tag_size - 16) / entry_size;

            var i: usize = 0;
            while (i < entry_count and mem_count < MAX_MEMORY_ENTRIES) : (i += 1) {
                const entry_addr = tag_addr + 16 + (i * entry_size);
                const base = @as(*u64, @ptrFromInt(entry_addr)).*;
                const length = @as(*u64, @ptrFromInt(entry_addr + 8)).*;
                const entry_type = @as(*u32, @ptrFromInt(entry_addr + 16)).*;

                memory_entries[mem_count] = MemoryEntry{
                    .base = base,
                    .length = length,
                    .entry_type = entry_type,
                };
                mem_count += 1;

                serial.print("  ");
                serial.print_hex(base);
                serial.print(" - ");
                serial.print_hex(base + length - 1);
                serial.print(" (");
                serial.print_hex(length / (1024 * 1024));
                serial.print(" MB)");
                if (entry_type == 1) {
                    serial.print(" [Available]");
                } else {
                    serial.print(" [Reserved]");
                }
                serial.print("\n");
            }
        }

        offset += (tag_size + 7) & ~@as(u64, 7);
    }

    return memory_entries[0..mem_count];
}

pub fn parse_framebuffer(addr: u64) ?FramebufferInfo {
    const total_size = @as(*u32, @ptrFromInt(addr)).*;
    var offset: u64 = 8;

    while (offset < total_size) {
        const tag_addr = addr + offset;
        const tag_type = @as(*u32, @ptrFromInt(tag_addr)).*;
        const tag_size = @as(*u32, @ptrFromInt(tag_addr + 4)).*;

        if (tag_type == 0) break;

        // Framebuffer tag (type 8)
        if (tag_type == 8) {
            const fb_addr = @as(*u64, @ptrFromInt(tag_addr + 8)).*;
            const fb_pitch = @as(*u32, @ptrFromInt(tag_addr + 16)).*;
            const fb_width = @as(*u32, @ptrFromInt(tag_addr + 20)).*;
            const fb_height = @as(*u32, @ptrFromInt(tag_addr + 24)).*;
            const fb_bpp = @as(*u8, @ptrFromInt(tag_addr + 28)).*;
            const fb_type = @as(*u8, @ptrFromInt(tag_addr + 29)).*;

            serial.print("\n=== Framebuffer Info ===\n");
            serial.print("Address: ");
            serial.print_hex(fb_addr);
            serial.print("\n");
            serial.print("Resolution: ");
            serial.print_hex(fb_width);
            serial.print("x");
            serial.print_hex(fb_height);
            serial.print("\n");
            serial.print("Pitch: ");
            serial.print_hex(fb_pitch);
            serial.print("\n");
            serial.print("BPP: ");
            serial.print_hex(fb_bpp);
            serial.print("\n");

            return FramebufferInfo{
                .addr = fb_addr,
                .pitch = fb_pitch,
                .width = fb_width,
                .height = fb_height,
                .bpp = fb_bpp,
                .framebuffer_type = fb_type,
            };
        }

        offset += (tag_size + 7) & ~@as(u64, 7);
    }

    return null;
}
