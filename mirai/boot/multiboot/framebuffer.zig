//! Multiboot framebuffer parser

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("types.zig");

var saved: ?types.FramebufferInfo = null;

pub fn parse(addr: u64) ?types.FramebufferInfo {
    const total_size = @as(*u32, @ptrFromInt(addr)).*;
    var offset: u64 = 8;

    while (offset < total_size) {
        const tag_addr = addr + offset;
        const tag_type = @as(*u32, @ptrFromInt(tag_addr)).*;
        const tag_size = @as(*u32, @ptrFromInt(tag_addr + 4)).*;

        if (tag_type == 0) break;

        if (tag_type == 8) {
            const info = types.FramebufferInfo{
                .addr = @as(*u64, @ptrFromInt(tag_addr + 8)).*,
                .pitch = @as(*u32, @ptrFromInt(tag_addr + 16)).*,
                .width = @as(*u32, @ptrFromInt(tag_addr + 20)).*,
                .height = @as(*u32, @ptrFromInt(tag_addr + 24)).*,
                .bpp = @as(*u8, @ptrFromInt(tag_addr + 28)).*,
                .framebuffer_type = @as(*u8, @ptrFromInt(tag_addr + 29)).*,
            };

            serial.printf("Framebuffer: {x} {}x{} pitch={} bpp={}\n", .{
                info.addr, info.width, info.height, info.pitch, info.bpp,
            });

            return info;
        }

        offset += (tag_size + 7) & ~@as(u64, 7);
    }

    return null;
}

pub fn set(fb: types.FramebufferInfo) void {
    saved = fb;
}

pub fn get() ?types.FramebufferInfo {
    return saved;
}
