//! Kernel Entry

const boot = @import("boot.zig");
const asm_ops = @import("../asm/asm.zig");

pub const BootParams = boot.BootParams;

pub fn main(boot_params_ptr: *boot.BootParams) noreturn {
    if (!boot_params_ptr.is_valid()) {
        if (boot_params_ptr.framebuffer.base != 0) {
            draw_error_screen(boot_params_ptr);
        }
        asm_ops.cpu.halt.halt_loop();
    }

    draw_boot_screen(boot_params_ptr);
    asm_ops.cpu.halt.halt_loop();
}

fn draw_boot_screen(params: *boot.BootParams) void {
    const fb = params.framebuffer;
    const base: [*]u32 = @ptrFromInt(fb.base);
    const stride = fb.stride;

    const bg_color: u32 = switch (fb.pixel_format) {
        .rgb => 0x1E0030,
        .bgr => 0x30001E,
        else => 0x1E0030,
    };

    var row: u32 = 0;
    while (row < fb.height) : (row += 1) {
        var col: u32 = 0;
        while (col < fb.width) : (col += 1) {
            base[row * stride + col] = bg_color;
        }
    }

    const text_color: u32 = switch (fb.pixel_format) {
        .rgb => 0x00FFFF,
        .bgr => 0xFFFF00,
        else => 0x00FFFF,
    };

    const banner = [_][]const u8{
        "   A   K  K  III  BBB    A   ",
        "  A A  K K    I   B  B  A A  ",
        " AAAAA KK     I   BBB  AAAAA ",
        " A   A K K    I   B  B A   A ",
        " A   A K  K  III  BBB  A   A ",
    };

    const start_x = (fb.width - 29 * 8) / 2;
    const start_y = fb.height / 3;

    for (banner, 0..) |line, line_row| {
        for (line, 0..) |char, line_col| {
            if (char != ' ') {
                draw_block(base, stride, start_x + @as(u32, @truncate(line_col)) * 8, start_y + @as(u32, @truncate(line_row)) * 12, text_color);
            }
        }
    }

    const subtitle = "AkibaOS Kernel Loaded Successfully";
    const subtitle_x = (fb.width - @as(u32, @truncate(subtitle.len)) * 8) / 2;
    const subtitle_y = start_y + 80;

    for (0..subtitle.len) |idx| {
        draw_small_block(base, stride, subtitle_x + @as(u32, @truncate(idx)) * 8, subtitle_y, 0xFF80C0);
    }
}

fn draw_error_screen(params: *boot.BootParams) void {
    const fb = params.framebuffer;
    const base: [*]u32 = @ptrFromInt(fb.base);
    const stride = fb.stride;

    const error_color: u32 = switch (fb.pixel_format) {
        .rgb => 0xFF0000,
        .bgr => 0x0000FF,
        else => 0xFF0000,
    };

    var row: u32 = 0;
    while (row < fb.height) : (row += 1) {
        var col: u32 = 0;
        while (col < fb.width) : (col += 1) {
            base[row * stride + col] = error_color;
        }
    }
}

fn draw_block(base: [*]u32, stride: u32, x_pos: u32, y_pos: u32, color: u32) void {
    var dy: u32 = 0;
    while (dy < 10) : (dy += 1) {
        var dx: u32 = 0;
        while (dx < 6) : (dx += 1) {
            base[(y_pos + dy) * stride + x_pos + dx] = color;
        }
    }
}

fn draw_small_block(base: [*]u32, stride: u32, x_pos: u32, y_pos: u32, color: u32) void {
    var dy: u32 = 0;
    while (dy < 2) : (dy += 1) {
        var dx: u32 = 0;
        while (dx < 6) : (dx += 1) {
            base[(y_pos + dy) * stride + x_pos + dx] = color;
        }
    }
}
