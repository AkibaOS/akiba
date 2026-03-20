//! Render CPU Context

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");

const Context = types.Context;

pub fn render(context: *const Context) void {
    serial.printf("CPU Context:\n", .{});
    serial.printf("  RAX: %x  RBX: %x\n", .{ context.rax, context.rbx });
    serial.printf("  RCX: %x  RDX: %x\n", .{ context.rcx, context.rdx });
    serial.printf("  RSI: %x  RDI: %x\n", .{ context.rsi, context.rdi });
    serial.printf("  RBP: %x  RSP: %x\n", .{ context.rbp, context.rsp });
    serial.printf("  R8:  %x  R9:  %x\n", .{ context.r8, context.r9 });
    serial.printf("  R10: %x  R11: %x\n", .{ context.r10, context.r11 });
    serial.printf("  R12: %x  R13: %x\n", .{ context.r12, context.r13 });
    serial.printf("  R14: %x  R15: %x\n", .{ context.r14, context.r15 });
    serial.printf("  RIP: %x  RFLAGS: %x\n", .{ context.rip, context.rflags });
    serial.printf("\n", .{});

    render_control_registers(context);
    render_segment_registers(context);
}

fn render_control_registers(context: *const Context) void {
    serial.printf("Control Registers:\n", .{});
    serial.printf("  CR0: %x  CR2: %x\n", .{ context.cr0, context.cr2 });
    serial.printf("  CR3: %x  CR4: %x\n", .{ context.cr3, context.cr4 });
    serial.printf("\n", .{});
}

fn render_segment_registers(context: *const Context) void {
    serial.printf("Segment Registers:\n", .{});
    serial.printf("  CS: %x  DS: %x  ES: %x\n", .{ context.cs, context.ds, context.es });
    serial.printf("  FS: %x  GS: %x  SS: %x\n", .{ context.fs, context.gs, context.ss });
    serial.printf("\n", .{});
}
