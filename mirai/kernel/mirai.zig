//! Mirai - AkibaOS Kernel
//!
//! The kernel receives boot parameters from Hikari bootloader
//! and initializes the system.

const boot = @import("boot.zig");

pub export fn mirai(boot_params_ptr: *boot.BootParams) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    // Validate boot parameters
    if (!boot_params_ptr.is_valid()) {
        // Invalid boot params - halt with error pattern
        if (boot_params_ptr.framebuffer.base != 0) {
            draw_error_screen(boot_params_ptr);
        }
        halt();
    }

    // Draw success screen
    draw_boot_screen(boot_params_ptr);

    // Halt for now
    halt();
}

fn draw_boot_screen(params: *boot.BootParams) void {
    const fb = params.framebuffer;
    const base: [*]u32 = @ptrFromInt(fb.base);
    const stride = fb.stride;

    // Clear screen to dark purple (Akiba theme)
    const bg_color: u32 = switch (fb.pixel_format) {
        .rgb => 0x1E0030, // RGB
        .bgr => 0x30001E, // BGR
        else => 0x1E0030,
    };

    var y: u32 = 0;
    while (y < fb.height) : (y += 1) {
        var x: u32 = 0;
        while (x < fb.width) : (x += 1) {
            base[y * stride + x] = bg_color;
        }
    }

    // Draw "MIRAI" banner in cyan
    const text_color: u32 = switch (fb.pixel_format) {
        .rgb => 0x00FFFF, // RGB cyan
        .bgr => 0xFFFF00, // BGR cyan
        else => 0x00FFFF,
    };

    const banner = [_][]const u8{
        "  M   M  III  RRRR    A    III ",
        "  MM MM   I   R   R  A A    I  ",
        "  M M M   I   RRRR  AAAAA   I  ",
        "  M   M   I   R R   A   A   I  ",
        "  M   M  III  R  R  A   A  III ",
    };

    const start_x = (fb.width - 31 * 8) / 2;
    const start_y = fb.height / 3;

    for (banner, 0..) |line, row| {
        for (line, 0..) |char, col| {
            if (char != ' ') {
                draw_block(base, stride, start_x + @as(u32, @truncate(col)) * 8, start_y + @as(u32, @truncate(row)) * 12, text_color);
            }
        }
    }

    // Draw "AkibaOS" subtitle
    const subtitle = "AkibaOS Kernel Loaded Successfully";
    const subtitle_x = (fb.width - @as(u32, @truncate(subtitle.len)) * 8) / 2;
    const subtitle_y = start_y + 80;

    for (0..subtitle.len) |i| {
        draw_small_block(base, stride, subtitle_x + @as(u32, @truncate(i)) * 8, subtitle_y, 0xFF80C0);
    }
}

fn draw_error_screen(params: *boot.BootParams) void {
    const fb = params.framebuffer;
    const base: [*]u32 = @ptrFromInt(fb.base);
    const stride = fb.stride;

    // Fill with red
    const error_color: u32 = switch (fb.pixel_format) {
        .rgb => 0xFF0000,
        .bgr => 0x0000FF,
        else => 0xFF0000,
    };

    var y: u32 = 0;
    while (y < fb.height) : (y += 1) {
        var x: u32 = 0;
        while (x < fb.width) : (x += 1) {
            base[y * stride + x] = error_color;
        }
    }
}

fn draw_block(base: [*]u32, stride: u32, x: u32, y: u32, color: u32) void {
    var dy: u32 = 0;
    while (dy < 10) : (dy += 1) {
        var dx: u32 = 0;
        while (dx < 6) : (dx += 1) {
            base[(y + dy) * stride + x + dx] = color;
        }
    }
}

fn draw_small_block(base: [*]u32, stride: u32, x: u32, y: u32, color: u32) void {
    var dy: u32 = 0;
    while (dy < 2) : (dy += 1) {
        var dx: u32 = 0;
        while (dx < 6) : (dx += 1) {
            base[(y + dy) * stride + x + dx] = color;
        }
    }
}

fn halt() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn panic(msg: []const u8, stack_trace: ?*@import("std").builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = stack_trace;
    _ = ret_addr;
    halt();
}
