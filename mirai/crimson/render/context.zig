//! Render CPU Context

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const messages = @import("../strings/strings.zig").messages;

const Context = types.Context;

pub fn render(context: *const Context) void {
    serial.printf(messages.cpu_context_header, .{});
    serial.printf(messages.reg_rax_rbx, .{ context.rax, context.rbx });
    serial.printf(messages.reg_rcx_rdx, .{ context.rcx, context.rdx });
    serial.printf(messages.reg_rsi_rdi, .{ context.rsi, context.rdi });
    serial.printf(messages.reg_rbp_rsp, .{ context.rbp, context.rsp });
    serial.printf(messages.reg_r8_r9, .{ context.r8, context.r9 });
    serial.printf(messages.reg_r10_r11, .{ context.r10, context.r11 });
    serial.printf(messages.reg_r12_r13, .{ context.r12, context.r13 });
    serial.printf(messages.reg_r14_r15, .{ context.r14, context.r15 });
    serial.printf(messages.reg_rip_rflags, .{ context.rip, context.rflags });
    serial.printf("\n", .{});

    render_control_registers(context);
    render_segment_registers(context);
}

fn render_control_registers(context: *const Context) void {
    serial.printf(messages.control_registers_header, .{});
    serial.printf(messages.reg_cr0_cr2, .{ context.cr0, context.cr2 });
    serial.printf(messages.reg_cr3_cr4, .{ context.cr3, context.cr4 });
    serial.printf("\n", .{});
}

fn render_segment_registers(context: *const Context) void {
    serial.printf(messages.segment_registers_header, .{});
    serial.printf(messages.reg_cs_ds_es, .{ context.cs, context.ds, context.es });
    serial.printf(messages.reg_fs_gs_ss, .{ context.fs, context.gs, context.ss });
    serial.printf("\n", .{});
}
