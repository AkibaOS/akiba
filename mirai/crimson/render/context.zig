//! Render CPU Context

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const messages = @import("../strings/strings.zig").messages;

const Context = types.Context;

pub fn render(context: *const Context) void {
    serial.printf(messages.CPU_CONTEXT_HEADER, .{});
    serial.printf(messages.REG_RAX_RBX, .{ context.rax, context.rbx });
    serial.printf(messages.REG_RCX_RDX, .{ context.rcx, context.rdx });
    serial.printf(messages.REG_RSI_RDI, .{ context.rsi, context.rdi });
    serial.printf(messages.REG_RBP_RSP, .{ context.rbp, context.rsp });
    serial.printf(messages.REG_R8_R9, .{ context.r8, context.r9 });
    serial.printf(messages.REG_R10_R11, .{ context.r10, context.r11 });
    serial.printf(messages.REG_R12_R13, .{ context.r12, context.r13 });
    serial.printf(messages.REG_R14_R15, .{ context.r14, context.r15 });
    serial.printf(messages.REG_RIP_RFLAGS, .{ context.rip, context.rflags });
    serial.printf("\n", .{});

    render_control_registers(context);
    render_segment_registers(context);
}

fn render_control_registers(context: *const Context) void {
    serial.printf(messages.CONTROL_REGISTERS_HEADER, .{});
    serial.printf(messages.REG_CR0_CR2, .{ context.cr0, context.cr2 });
    serial.printf(messages.REG_CR3_CR4, .{ context.cr3, context.cr4 });
    serial.printf("\n", .{});
}

fn render_segment_registers(context: *const Context) void {
    serial.printf(messages.SEGMENT_REGISTERS_HEADER, .{});
    serial.printf(messages.REG_CS_DS_ES, .{ context.cs, context.ds, context.es });
    serial.printf(messages.REG_FS_GS_SS, .{ context.fs, context.gs, context.ss });
    serial.printf("\n", .{});
}
