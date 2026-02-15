//! Crimson panic handler

const cpu = @import("../asm/cpu.zig");
const crimson_limits = @import("../common/limits/crimson.zig");
const format = @import("format.zig");
const multiboot = @import("../boot/multiboot/multiboot.zig");
const render = @import("render.zig");
const serial = @import("../drivers/serial/serial.zig");
const types = @import("types.zig");

var framebuffer: ?multiboot.FramebufferInfo = null;

pub fn init(fb: multiboot.FramebufferInfo) void {
    framebuffer = fb;
    serial.print("Crimson panic handler initialized\n");
}

pub fn collapse(message: []const u8, context: ?*const types.Context) noreturn {
    cpu.disable_interrupts();

    serial.print("\n╔════════════════════════════════════╗\n");
    serial.print("║        CRIMSON COLLAPSE            ║\n");
    serial.print("╚════════════════════════════════════╝\n");
    serial.print(message);
    serial.print("\n");

    if (context) |ctx| {
        dump_registers(ctx);
    }

    if (framebuffer) |fb| {
        render.screen(fb, message, context);
    }

    halt();
}

pub fn assert_failed(condition: []const u8, file: []const u8, line: u32) noreturn {
    var buffer: [crimson_limits.ASSERT_BUFFER_SIZE]u8 = undefined;
    const msg = format.assert_message(condition, file, line, &buffer);
    collapse(msg, null);
}

fn dump_registers(ctx: *const types.Context) void {
    serial.print("\nRegister Dump:\n");
    serial.printf("RAX: {x}  RBX: {x}\n", .{ ctx.rax, ctx.rbx });
    serial.printf("RCX: {x}  RDX: {x}\n", .{ ctx.rcx, ctx.rdx });
    serial.printf("RSI: {x}  RDI: {x}\n", .{ ctx.rsi, ctx.rdi });
    serial.printf("RBP: {x}  RSP: {x}\n", .{ ctx.rbp, ctx.rsp });
    serial.printf("RIP: {x}  CR2: {x}\n", .{ ctx.rip, ctx.cr2 });
    serial.printf("CR3: {x}  ERR: {x}\n", .{ ctx.cr3, ctx.error_code });

    serial.print("\nFaulting instruction bytes at RIP:\n  ");
    const rip_ptr = @as([*]const u8, @ptrFromInt(ctx.rip));
    for (0..16) |i| {
        serial.printf("{x} ", .{rip_ptr[i]});
    }
    serial.print("\n");
}

fn halt() noreturn {
    while (true) {
        cpu.disable_interrupts();
        cpu.halt_processor();
    }
}
