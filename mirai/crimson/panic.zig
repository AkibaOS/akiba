//! Crimson Panic Handler - "Hey! You finally met Crimson!"

const boot = @import("../boot/multiboot2.zig");
const font = @import("../graphics/fonts/psf.zig");
const serial = @import("../drivers/serial.zig");

// Crimson color scheme
const CRIMSON_BG: u32 = 0x00DC143C; // Crimson red
const WHITE_FG: u32 = 0x00FFFFFF; // White text

var framebuffer: ?boot.FramebufferInfo = null;

// Register context at time of collapse
pub const Context = struct {
    rax: u64,
    rbx: u64,
    rcx: u64,
    rdx: u64,
    rsi: u64,
    rdi: u64,
    rbp: u64,
    rsp: u64,
    r8: u64,
    r9: u64,
    r10: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,
    rip: u64,
    rflags: u64,
    error_code: u64,
    cr2: u64, // Page fault address
    cr3: u64, // Page table address
};

const MAX_STACK_FRAMES = 16;

// Initialize panic handler with framebuffer
pub fn init(fb: boot.FramebufferInfo) void {
    framebuffer = fb;
    serial.print("Crimson panic handler initialized\n");
}

// Main collapse function - called on fatal errors
pub fn collapse(message: []const u8, context: ?*const Context) noreturn {
    // Disable interrupts immediately
    asm volatile ("cli");

    // Log to serial first (in case framebuffer fails)
    serial.print("\n╔════════════════════════════════════╗\n");
    serial.print("║        CRIMSON COLLAPSE            ║\n");
    serial.print("╚════════════════════════════════════╝\n");
    serial.print(message);
    serial.print("\n");

    if (context) |ctx| {
        dump_registers_serial(ctx);
    }

    // Render to screen if framebuffer available
    if (framebuffer) |fb| {
        render_crimson_screen(fb, message, context);
    }

    halt();
}

// Assert macro helper
pub fn assert_failed(condition: []const u8, file: []const u8, line: u32) noreturn {
    var buffer: [256]u8 = undefined;
    const msg = format_assert_message(condition, file, line, &buffer);
    collapse(msg, null);
}

fn format_assert_message(condition: []const u8, file: []const u8, line: u32, buffer: []u8) []const u8 {
    var pos: usize = 0;

    // "Assertion failed: "
    const prefix = "Assertion failed: ";
    for (prefix) |c| {
        if (pos < buffer.len) {
            buffer[pos] = c;
            pos += 1;
        }
    }

    // Condition
    for (condition) |c| {
        if (pos < buffer.len) {
            buffer[pos] = c;
            pos += 1;
        }
    }

    // " at "
    const at_str = " at ";
    for (at_str) |c| {
        if (pos < buffer.len) {
            buffer[pos] = c;
            pos += 1;
        }
    }

    // File
    for (file) |c| {
        if (pos < buffer.len) {
            buffer[pos] = c;
            pos += 1;
        }
    }

    // ":"
    if (pos < buffer.len) {
        buffer[pos] = ':';
        pos += 1;
    }

    // Line number
    pos += format_u32(line, buffer[pos..]);

    return buffer[0..pos];
}

fn format_u32(value: u32, buffer: []u8) usize {
    if (buffer.len == 0) return 0;

    var temp: [10]u8 = undefined;
    var temp_pos: usize = 0;
    var val = value;

    if (val == 0) {
        buffer[0] = '0';
        return 1;
    }

    while (val > 0 and temp_pos < 10) {
        temp[temp_pos] = @as(u8, @truncate(val % 10)) + '0';
        val /= 10;
        temp_pos += 1;
    }

    var pos: usize = 0;
    while (temp_pos > 0 and pos < buffer.len) {
        temp_pos -= 1;
        buffer[pos] = temp[temp_pos];
        pos += 1;
    }

    return pos;
}

fn render_crimson_screen(fb: boot.FramebufferInfo, message: []const u8, context: ?*const Context) void {
    // Fill screen with crimson
    fill_screen_crimson(fb);

    const char_height = font.get_height();
    var y: u32 = 60;

    // Heading
    const heading = "Hey! You finally met Crimson!";
    render_centered_text(heading, y, fb, WHITE_FG);
    y += char_height + 20;

    // Description
    const desc1 = "Mirai Kernel has encountered an error and the system";
    const desc2 = "will need to be restarted. Please reboot your machine.";
    render_centered_text(desc1, y, fb, WHITE_FG);
    y += char_height + 4;
    render_centered_text(desc2, y, fb, WHITE_FG);
    y += char_height + 30;

    // Error message
    render_centered_text("Error:", y, fb, WHITE_FG);
    y += char_height + 4;
    render_centered_text(message, y, fb, WHITE_FG);
    y += char_height + 30;

    // Registers if context provided
    if (context) |ctx| {
        render_registers(ctx, y, fb);
        y += (char_height + 4) * 10; // Space for registers

        // Stack trace
        render_centered_text("Stack Trace:", y, fb, WHITE_FG);
        y += char_height + 4;
        render_stack_trace(ctx.rbp, ctx.rip, y, fb);
    }
}

fn fill_screen_crimson(fb: boot.FramebufferInfo) void {
    if (fb.bpp == 32) {
        const pixels = @as([*]volatile u32, @ptrFromInt(fb.addr));
        const total_pixels = fb.height * (fb.pitch / 4);

        var i: u32 = 0;
        while (i < total_pixels) : (i += 1) {
            pixels[i] = CRIMSON_BG;
        }
    } else if (fb.bpp == 24) {
        const pixels = @as([*]volatile u8, @ptrFromInt(fb.addr));

        const r: u8 = @truncate((CRIMSON_BG >> 16) & 0xFF);
        const g: u8 = @truncate((CRIMSON_BG >> 8) & 0xFF);
        const b: u8 = @truncate(CRIMSON_BG & 0xFF);

        var y: u32 = 0;
        while (y < fb.height) : (y += 1) {
            var x: u32 = 0;
            while (x < fb.width) : (x += 1) {
                const offset = y * fb.pitch + x * 3;
                pixels[offset] = b;
                pixels[offset + 1] = g;
                pixels[offset + 2] = r;
            }
        }
    }
}

fn render_centered_text(text: []const u8, y: u32, fb: boot.FramebufferInfo, color: u32) void {
    const char_width: u32 = font.get_width();
    const text_width: u32 = @intCast(text.len * char_width);

    if (text_width > fb.width) {
        // Text too long, left-align with margin
        font.render_text(text, 20, y, fb, color);
    } else {
        const x: u32 = (fb.width - text_width) / 2;
        font.render_text(text, x, y, fb, color);
    }
}

fn render_registers(ctx: *const Context, start_y: u32, fb: boot.FramebufferInfo) void {
    const char_height = font.get_height();
    var y = start_y;

    var buffer: [100]u8 = undefined;

    // Two-column layout for registers
    render_register_pair("RAX", ctx.rax, "RBX", ctx.rbx, y, &buffer, fb);
    y += char_height + 4;

    render_register_pair("RCX", ctx.rcx, "RDX", ctx.rdx, y, &buffer, fb);
    y += char_height + 4;

    render_register_pair("RSI", ctx.rsi, "RDI", ctx.rdi, y, &buffer, fb);
    y += char_height + 4;

    render_register_pair("RBP", ctx.rbp, "RSP", ctx.rsp, y, &buffer, fb);
    y += char_height + 4;

    render_register_pair("R8 ", ctx.r8, "R9 ", ctx.r9, y, &buffer, fb);
    y += char_height + 4;

    render_register_pair("R10", ctx.r10, "R11", ctx.r11, y, &buffer, fb);
    y += char_height + 4;

    render_register_pair("R12", ctx.r12, "R13", ctx.r13, y, &buffer, fb);
    y += char_height + 4;

    render_register_pair("R14", ctx.r14, "R15", ctx.r15, y, &buffer, fb);
    y += char_height + 4;

    render_register_pair("RIP", ctx.rip, "CR2", ctx.cr2, y, &buffer, fb);
    y += char_height + 4;

    render_register_pair("CR3", ctx.cr3, "ERR", ctx.error_code, y, &buffer, fb);
}

fn render_register_pair(label1: []const u8, val1: u64, label2: []const u8, val2: u64, y: u32, buffer: []u8, fb: boot.FramebufferInfo) void {
    // Left column
    const left_x: u32 = 100;
    const right_x: u32 = 500;

    const text1 = format_register(label1, val1, buffer[0..49]);
    font.render_text(text1, left_x, y, fb, WHITE_FG);

    const text2 = format_register(label2, val2, buffer[50..99]);
    font.render_text(text2, right_x, y, fb, WHITE_FG);
}

fn format_register(label: []const u8, value: u64, buffer: []u8) []const u8 {
    var pos: usize = 0;

    // Label
    for (label) |c| {
        if (pos < buffer.len) {
            buffer[pos] = c;
            pos += 1;
        }
    }

    // Separator
    if (pos < buffer.len) {
        buffer[pos] = ':';
        pos += 1;
    }
    if (pos < buffer.len) {
        buffer[pos] = ' ';
        pos += 1;
    }

    // Hex value
    const hex_chars = "0123456789ABCDEF";
    var shift: u6 = 60;
    var i: usize = 0;
    while (i < 16 and pos < buffer.len) : (i += 1) {
        const nibble = @as(u8, @truncate((value >> shift) & 0xF));
        buffer[pos] = hex_chars[nibble];
        pos += 1;
        if (shift >= 4) {
            shift -= 4;
        }
    }

    return buffer[0..pos];
}

fn render_stack_trace(rbp: u64, rip: u64, start_y: u32, fb: boot.FramebufferInfo) void {
    const char_height = font.get_height();
    var y = start_y;
    var buffer: [50]u8 = undefined;

    // First frame is current RIP
    const text0 = format_stack_frame(0, rip, &buffer);
    render_centered_text(text0, y, fb, WHITE_FG);
    y += char_height + 2;

    // Walk stack
    var frame_rbp = rbp;
    var frame_num: usize = 1;

    while (frame_num < MAX_STACK_FRAMES) : (frame_num += 1) {
        // Check if RBP looks valid (in higher half)
        if (frame_rbp < 0xFFFF800000000000 or frame_rbp == 0) break;

        // Read return address (RBP+8)
        const ret_addr_ptr = @as(*const u64, @ptrFromInt(frame_rbp + 8));
        const ret_addr = ret_addr_ptr.*;

        // Check if return address looks valid
        if (ret_addr < 0xFFFF800000000000) break;

        const text = format_stack_frame(frame_num, ret_addr, &buffer);
        render_centered_text(text, y, fb, WHITE_FG);
        y += char_height + 2;

        // Get next frame
        const next_rbp_ptr = @as(*const u64, @ptrFromInt(frame_rbp));
        frame_rbp = next_rbp_ptr.*;

        // Prevent infinite loops
        if (frame_rbp == 0 or frame_rbp == rbp) break;
    }
}

fn format_stack_frame(num: usize, addr: u64, buffer: []u8) []const u8 {
    var pos: usize = 0;

    // Frame number
    if (pos < buffer.len) {
        buffer[pos] = '#';
        pos += 1;
    }
    pos += format_u32(@truncate(num), buffer[pos..]);

    // Separator
    if (pos < buffer.len) {
        buffer[pos] = ' ';
        pos += 1;
    }

    // Address
    const hex_chars = "0123456789ABCDEF";
    var shift: u6 = 60;
    var i: usize = 0;
    while (i < 16 and pos < buffer.len) : (i += 1) {
        const nibble = @as(u8, @truncate((addr >> shift) & 0xF));
        buffer[pos] = hex_chars[nibble];
        pos += 1;
        if (shift >= 4) {
            shift -= 4;
        }
    }

    return buffer[0..pos];
}

fn dump_registers_serial(ctx: *const Context) void {
    serial.print("\nRegister Dump:\n");
    serial.print("RAX: ");
    serial.print_hex(ctx.rax);
    serial.print("  RBX: ");
    serial.print_hex(ctx.rbx);
    serial.print("\n");

    serial.print("RCX: ");
    serial.print_hex(ctx.rcx);
    serial.print("  RDX: ");
    serial.print_hex(ctx.rdx);
    serial.print("\n");

    serial.print("RSI: ");
    serial.print_hex(ctx.rsi);
    serial.print("  RDI: ");
    serial.print_hex(ctx.rdi);
    serial.print("\n");

    serial.print("RBP: ");
    serial.print_hex(ctx.rbp);
    serial.print("  RSP: ");
    serial.print_hex(ctx.rsp);
    serial.print("\n");

    serial.print("RIP: ");
    serial.print_hex(ctx.rip);
    serial.print("  CR2: ");
    serial.print_hex(ctx.cr2);
    serial.print("\n");

    serial.print("CR3: ");
    serial.print_hex(ctx.cr3);
    serial.print("  ERR: ");
    serial.print_hex(ctx.error_code);
    serial.print("\n");
}

fn halt() noreturn {
    while (true) {
        asm volatile ("cli; hlt");
    }
}
