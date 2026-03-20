//! Dump Context for Debugging

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const Context = types.Context;

pub fn dump_context(ctx: *const Context) void {
    serial.printf("RAX: %x  RBX: %x  RCX: %x  RDX: %x\n", .{ ctx.rax, ctx.rbx, ctx.rcx, ctx.rdx });
    serial.printf("RSI: %x  RDI: %x  RBP: %x  RSP: %x\n", .{ ctx.rsi, ctx.rdi, ctx.rbp, ctx.rsp });
    serial.printf("R8:  %x  R9:  %x  R10: %x  R11: %x\n", .{ ctx.r8, ctx.r9, ctx.r10, ctx.r11 });
    serial.printf("R12: %x  R13: %x  R14: %x  R15: %x\n", .{ ctx.r12, ctx.r13, ctx.r14, ctx.r15 });
    serial.printf("RIP: %x  RFLAGS: %x\n", .{ ctx.rip, ctx.rflags });
    serial.printf("CR0: %x  CR2: %x  CR3: %x  CR4: %x\n", .{ ctx.cr0, ctx.cr2, ctx.cr3, ctx.cr4 });
}
