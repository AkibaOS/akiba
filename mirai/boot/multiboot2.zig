//! Multiboot2 boot protocol parser

const serial = @import("../drivers/serial.zig");

pub const FramebufferInfo = struct {
    addr: u64,
    pitch: u32,
    width: u32,
    height: u32,
};

pub fn parse_multiboot2(addr: u64) ?FramebufferInfo {
    serial.print("Memory Map:\r\n");

    const total_size = @as(*u32, @ptrFromInt(addr)).*;
    var offset: u64 = 8;

    var fb_info: ?FramebufferInfo = null;
    var total_ram: u64 = 0;

    while (offset < total_size) {
        const tag_addr = addr + offset;
        const tag_type = @as(*u32, @ptrFromInt(tag_addr)).*;
        const tag_size = @as(*u32, @ptrFromInt(tag_addr + 4)).*;

        if (tag_type == 0) break;

        if (tag_type == 6) {
            const entry_size = @as(*u32, @ptrFromInt(tag_addr + 8)).*;
            const entry_count = (tag_size - 16) / entry_size;

            var i: usize = 0;
            while (i < entry_count) : (i += 1) {
                const entry_addr = tag_addr + 16 + (i * entry_size);
                const base = @as(*u64, @ptrFromInt(entry_addr)).*;
                const length = @as(*u64, @ptrFromInt(entry_addr + 8)).*;
                const entry_type = @as(*u32, @ptrFromInt(entry_addr + 16)).*;

                serial.print("  Base: ");
                serial.print_hex(base);
                serial.print(" Len: ");
                serial.print_hex(length);
                serial.print(" Type: ");
                serial.print_hex(entry_type);

                if (entry_type == 1) {
                    serial.print(" (Available)");
                    total_ram += length;
                }
                serial.print("\r\n");
            }
        }

        if (tag_type == 8) {
            const fb_addr = @as(*u64, @ptrFromInt(tag_addr + 8)).*;
            const fb_pitch = @as(*u32, @ptrFromInt(tag_addr + 16)).*;
            const fb_width = @as(*u32, @ptrFromInt(tag_addr + 20)).*;
            const fb_height = @as(*u32, @ptrFromInt(tag_addr + 24)).*;
            const fb_bpp = @as(*u8, @ptrFromInt(tag_addr + 28)).*;

            serial.print("Framebuffer: ");
            serial.print_hex(fb_width);
            serial.print("x");
            serial.print_hex(fb_height);
            serial.print(" @ ");
            serial.print_hex(fb_bpp);
            serial.print(" bpp\r\n");

            fb_info = FramebufferInfo{
                .addr = fb_addr,
                .pitch = fb_pitch,
                .width = fb_width,
                .height = fb_height,
            };
        }

        offset += (tag_size + 7) & ~@as(u64, 7);
    }

    serial.print("Total RAM: ");
    serial.print_hex(total_ram);
    serial.print(" (");
    serial.print_hex(total_ram / (1024 * 1024));
    serial.print(" MB)\r\n");

    return fb_info;
}
