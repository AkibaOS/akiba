//! Dump Context for Debugging

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const messages = @import("../strings/strings.zig").messages;
const Context = types.Context;

pub fn dump_context(ctx: *const Context) void {
    serial.printf(messages.DUMP_REGISTERS_GENERAL_1, .{ ctx.rax, ctx.rbx, ctx.rcx, ctx.rdx });
    serial.printf(messages.DUMP_REGISTERS_GENERAL_2, .{ ctx.rsi, ctx.rdi, ctx.rbp, ctx.rsp });
    serial.printf(messages.DUMP_REGISTERS_GENERAL_3, .{ ctx.r8, ctx.r9, ctx.r10, ctx.r11 });
    serial.printf(messages.DUMP_REGISTERS_GENERAL_4, .{ ctx.r12, ctx.r13, ctx.r14, ctx.r15 });
    serial.printf(messages.DUMP_REGISTERS_INSTRUCTION, .{ ctx.rip, ctx.rflags });
    serial.printf(messages.DUMP_REGISTERS_CONTROL, .{ ctx.cr0, ctx.cr2, ctx.cr3, ctx.cr4 });
}
