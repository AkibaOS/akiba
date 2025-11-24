fn write_serial(byte: u8) void {
    while ((inb(0x3F8 + 5) & 0x20) == 0) {}
    outb(0x3F8, byte);
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

fn init_serial() void {
    outb(0x3F8 + 1, 0x00);
    outb(0x3F8 + 3, 0x80);
    outb(0x3F8 + 0, 0x03);
    outb(0x3F8 + 1, 0x00);
    outb(0x3F8 + 3, 0x03);
    outb(0x3F8 + 2, 0xC7);
    outb(0x3F8 + 4, 0x0B);
}

fn write_string(str: []const u8) void {
    for (str) |c| {
        write_serial(c);
    }
}

fn write_hex(value: u64) void {
    const hex_chars = "0123456789ABCDEF";
    var i: u6 = 0;
    while (i < 16) : (i += 1) {
        const shift: u6 = 60 - (i * 4);
        const nibble = @as(u8, @truncate((value >> @intCast(shift)) & 0xF));
        write_serial(hex_chars[nibble]);
    }
}

const FramebufferInfo = struct {
    addr: u64,
    width: u32,
    height: u32,
    pitch: u32,
};

fn parse_multiboot2(info_addr: u64) ?FramebufferInfo {
    const info = @as([*]u8, @ptrFromInt(info_addr));
    const total_size = @as(*align(1) u32, @ptrCast(info)).*;

    var offset: u32 = 8;
    var total_memory: u64 = 0;

    while (offset < total_size) {
        const tag_type = @as(*align(1) u32, @ptrCast(info + offset)).*;
        const tag_size = @as(*align(1) u32, @ptrCast(info + offset + 4)).*;

        if (tag_type == 0) break;

        // Type 6 = memory map
        if (tag_type == 6) {
            write_string("\nMemory Map:\r\n");
            const entry_size = @as(*align(1) u32, @ptrCast(info + offset + 8)).*;
            const entry_version = @as(*align(1) u32, @ptrCast(info + offset + 12)).*;

            write_string("Entry size: ");
            write_hex(entry_size);
            write_string(" version: ");
            write_hex(entry_version);
            write_string("\r\n");

            var entry_offset: u32 = 16;
            while (entry_offset < tag_size) {
                const base_addr = @as(*align(1) u64, @ptrCast(info + offset + entry_offset)).*;
                const length = @as(*align(1) u64, @ptrCast(info + offset + entry_offset + 8)).*;
                const entry_type = @as(*align(1) u32, @ptrCast(info + offset + entry_offset + 16)).*;

                write_string("  Base: 0x");
                write_hex(base_addr);
                write_string(" Length: 0x");
                write_hex(length);
                write_string(" Type: ");
                write_hex(entry_type);

                if (entry_type == 1) {
                    write_string(" (Available)");
                    total_memory += length;
                }
                write_string("\r\n");

                entry_offset += entry_size;
            }

            write_string("Total available RAM: 0x");
            write_hex(total_memory);
            write_string(" (");
            write_hex(total_memory / (1024 * 1024));
            write_string(" MB)\r\n");
        }

        // Type 8 = framebuffer info
        if (tag_type == 8) {
            const fb_addr = @as(*align(1) u64, @ptrCast(info + offset + 8)).*;
            const fb_pitch = @as(*align(1) u32, @ptrCast(info + offset + 16)).*;
            const fb_width = @as(*align(1) u32, @ptrCast(info + offset + 20)).*;
            const fb_height = @as(*align(1) u32, @ptrCast(info + offset + 24)).*;
            const fb_bpp = @as(*align(1) u8, @ptrCast(info + offset + 28)).*;
            const fb_type = @as(*align(1) u8, @ptrCast(info + offset + 29)).*;

            write_string("\nFramebuffer details:\r\n");
            write_string("  BPP (bits per pixel): ");
            write_hex(fb_bpp);
            write_string("\r\n  Type: ");
            write_hex(fb_type);
            write_string("\r\n  Bytes per pixel: ");
            write_hex(fb_bpp / 8);
            write_string("\r\n");

            return FramebufferInfo{
                .addr = fb_addr,
                .width = fb_width,
                .height = fb_height,
                .pitch = fb_pitch,
            };
        }

        offset += (tag_size + 7) & ~@as(u32, 7);
    }

    return null;
}

fn fill_screen(fb: FramebufferInfo, r: u8, g: u8, b: u8) void {
    write_string("\nFilling screen...\r\n");

    const framebuffer = @as([*]volatile u8, @ptrFromInt(fb.addr));

    // Draw only first 100 rows to test
    var y: u32 = 0;
    while (y < 100) : (y += 1) {
        if (y % 10 == 0) {
            write_string("Row: ");
            write_hex(y);
            write_string("\r\n");
        }

        var x: u32 = 0;
        while (x < fb.width) : (x += 1) {
            const pixel_offset = y * fb.pitch + x * 3;
            framebuffer[pixel_offset + 0] = b;
            framebuffer[pixel_offset + 1] = g;
            framebuffer[pixel_offset + 2] = r;
        }
    }

    write_string("Screen filled!\r\n");
}

fn draw_big_test(fb: FramebufferInfo) void {
    write_string("\nFilling screen row by row (respecting pitch)...\r\n");

    const framebuffer = @as([*]volatile u8, @ptrFromInt(fb.addr));

    write_string("Width: ");
    write_hex(fb.width);
    write_string(" Height: ");
    write_hex(fb.height);
    write_string(" Pitch: ");
    write_hex(fb.pitch);
    write_string("\r\n");

    var y: u32 = 0;
    while (y < fb.height) : (y += 1) {
        const row_offset = y * fb.pitch;

        var x: u32 = 0;
        while (x < fb.width) : (x += 1) {
            const pixel_offset = row_offset + x * 3;
            framebuffer[pixel_offset + 0] = 255; // Blue
            framebuffer[pixel_offset + 1] = 0; // Green
            framebuffer[pixel_offset + 2] = 255; // Red
        }

        if (y % 50 == 0) {
            write_string("Row: ");
            write_hex(y);
            write_string("\r\n");
        }
    }

    write_string("Screen filled!\r\n");
}

export fn mirai(multiboot_info_addr: u64) noreturn {
    init_serial();
    write_string("Akiba kernel started!\r\n");
    write_string("We have 4GB mapped for early boot.\r\n");

    if (parse_multiboot2(multiboot_info_addr)) |fb| {
        write_string("Framebuffer found at: 0x");
        write_hex(fb.addr);
        write_string("\r\n");

        draw_big_test(fb);
    } else {
        write_string("No framebuffer found!\r\n");
    }
    while (true) {}
}
