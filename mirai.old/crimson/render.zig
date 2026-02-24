//! Crimson screen rendering

const colors = @import("../common/constants/colors.zig");
const crimson_limits = @import("../common/limits/crimson.zig");
const font = @import("../graphics/fonts/psf.zig");
const format = @import("format.zig");
const multiboot = @import("../boot/multiboot/multiboot.zig");
const types = @import("types.zig");
const video_const = @import("../common/constants/video.zig");

pub fn screen(fb: multiboot.FramebufferInfo, message: []const u8, context: ?*const types.Context) void {
    fill_crimson(fb);

    const char_height = font.get_height();
    var y: u32 = 60;

    const heading = "Hey! You finally met Crimson!";
    centered_text(heading, y, fb, colors.WHITE);
    y += char_height + 20;

    const desc1 = "Mirai Kernel has encountered an error and the system";
    const desc2 = "will need to be restarted. Please reboot your machine.";
    centered_text(desc1, y, fb, colors.WHITE);
    y += char_height + 4;
    centered_text(desc2, y, fb, colors.WHITE);
    y += char_height + 30;

    centered_text("Error:", y, fb, colors.WHITE);
    y += char_height + 4;
    centered_text(message, y, fb, colors.WHITE);
    y += char_height + 30;

    if (context) |ctx| {
        registers(ctx, y, fb);
        y += (char_height + 4) * 10;

        centered_text("Stack Trace:", y, fb, colors.WHITE);
        y += char_height + 4;
        stack_trace(ctx.rbp, ctx.rip, y, fb);
    }
}

fn fill_crimson(fb: multiboot.FramebufferInfo) void {
    if (fb.bpp == video_const.BPP_32) {
        const pixels = @as([*]volatile u32, @ptrFromInt(fb.addr));
        const total = fb.height * (fb.pitch / 4);

        for (0..total) |i| {
            pixels[i] = colors.CRIMSON;
        }
    } else if (fb.bpp == video_const.BPP_24) {
        const pixels = @as([*]volatile u8, @ptrFromInt(fb.addr));

        const r: u8 = @truncate((colors.CRIMSON >> 16) & 0xFF);
        const g: u8 = @truncate((colors.CRIMSON >> 8) & 0xFF);
        const b: u8 = @truncate(colors.CRIMSON & 0xFF);

        for (0..fb.height) |y| {
            for (0..fb.width) |x| {
                const offset = y * fb.pitch + x * 3;
                pixels[offset] = b;
                pixels[offset + 1] = g;
                pixels[offset + 2] = r;
            }
        }
    }
}

pub fn centered_text(text: []const u8, y: u32, fb: multiboot.FramebufferInfo, color: u32) void {
    const char_width: u32 = font.get_width();
    const text_width: u32 = @intCast(text.len * char_width);

    if (text_width > fb.width) {
        font.render_text(text, 20, y, fb, color);
    } else {
        const x: u32 = (fb.width - text_width) / 2;
        font.render_text(text, x, y, fb, color);
    }
}

fn registers(ctx: *const types.Context, start_y: u32, fb: multiboot.FramebufferInfo) void {
    const char_height = font.get_height();
    var y = start_y;
    var buffer: [crimson_limits.REGISTER_BUFFER_SIZE]u8 = undefined;

    register_pair("RAX", ctx.rax, "RBX", ctx.rbx, y, &buffer, fb);
    y += char_height + 4;

    register_pair("RCX", ctx.rcx, "RDX", ctx.rdx, y, &buffer, fb);
    y += char_height + 4;

    register_pair("RSI", ctx.rsi, "RDI", ctx.rdi, y, &buffer, fb);
    y += char_height + 4;

    register_pair("RBP", ctx.rbp, "RSP", ctx.rsp, y, &buffer, fb);
    y += char_height + 4;

    register_pair("R8 ", ctx.r8, "R9 ", ctx.r9, y, &buffer, fb);
    y += char_height + 4;

    register_pair("R10", ctx.r10, "R11", ctx.r11, y, &buffer, fb);
    y += char_height + 4;

    register_pair("R12", ctx.r12, "R13", ctx.r13, y, &buffer, fb);
    y += char_height + 4;

    register_pair("R14", ctx.r14, "R15", ctx.r15, y, &buffer, fb);
    y += char_height + 4;

    register_pair("RIP", ctx.rip, "CR2", ctx.cr2, y, &buffer, fb);
    y += char_height + 4;

    register_pair("CR3", ctx.cr3, "ERR", ctx.error_code, y, &buffer, fb);
}

fn register_pair(label1: []const u8, val1: u64, label2: []const u8, val2: u64, y: u32, buffer: []u8, fb: multiboot.FramebufferInfo) void {
    const left_x: u32 = 100;
    const right_x: u32 = 500;

    const text1 = format.register(label1, val1, buffer[0..49]);
    font.render_text(text1, left_x, y, fb, colors.WHITE);

    const text2 = format.register(label2, val2, buffer[50..99]);
    font.render_text(text2, right_x, y, fb, colors.WHITE);
}

fn stack_trace(rbp: u64, rip: u64, start_y: u32, fb: multiboot.FramebufferInfo) void {
    const char_height = font.get_height();
    var y = start_y;
    var buffer: [crimson_limits.STACK_FRAME_BUFFER_SIZE]u8 = undefined;

    const text0 = format.stack_frame(0, rip, &buffer);
    centered_text(text0, y, fb, colors.WHITE);
    y += char_height + 2;

    var frame_rbp = rbp;
    var frame_num: usize = 1;

    while (frame_num < crimson_limits.MAX_STACK_FRAMES) : (frame_num += 1) {
        if (frame_rbp < 0xFFFF800000000000 or frame_rbp == 0) break;

        const ret_addr = @as(*const u64, @ptrFromInt(frame_rbp + 8)).*;

        if (ret_addr < 0xFFFF800000000000) break;

        const text = format.stack_frame(frame_num, ret_addr, &buffer);
        centered_text(text, y, fb, colors.WHITE);
        y += char_height + 2;

        const next_rbp = @as(*const u64, @ptrFromInt(frame_rbp)).*;

        if (next_rbp == 0 or next_rbp == frame_rbp) break;
        frame_rbp = next_rbp;
    }
}
