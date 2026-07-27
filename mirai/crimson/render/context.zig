//! Render CPU Context

const serial = @import("../../drivers/serial/serial.zig");
const strings = @import("../strings/strings.zig");
const types = @import("../types/types.zig");

const messages = strings.messages;

const Context = types.context.Context;

pub fn render(context: *const Context) void {
    serial.write.printf(messages.CPU_CONTEXT_HEADER, .{});
    serial.write.printf(messages.REG_RAX_RBX, .{ context.RAX, context.RBX });
    serial.write.printf(messages.REG_RCX_RDX, .{ context.RCX, context.RDX });
    serial.write.printf(messages.REG_RSI_RDI, .{ context.RSI, context.RDI });
    serial.write.printf(messages.REG_RBP_RSP, .{ context.RBP, context.RSP });
    serial.write.printf(messages.REG_R8_R9, .{ context.R8, context.R9 });
    serial.write.printf(messages.REG_R10_R11, .{ context.R10, context.R11 });
    serial.write.printf(messages.REG_R12_R13, .{ context.R12, context.R13 });
    serial.write.printf(messages.REG_R14_R15, .{ context.R14, context.R15 });
    serial.write.printf(messages.REG_RIP_RFLAGS, .{ context.RIP, context.RFLAGS });
    serial.write.printf("\n", .{});

    renderControlRegisters(context);
    renderSegmentRegisters(context);
}

fn renderControlRegisters(context: *const Context) void {
    serial.write.printf(messages.CONTROL_REGISTERS_HEADER, .{});
    serial.write.printf(messages.REG_CR0_CR2, .{ context.CR0, context.CR2 });
    serial.write.printf(messages.REG_CR3_CR4, .{ context.CR3, context.CR4 });
    serial.write.printf("\n", .{});
}

fn renderSegmentRegisters(context: *const Context) void {
    serial.write.printf(messages.SEGMENT_REGISTERS_HEADER, .{});
    serial.write.printf(messages.REG_CS_DS_ES, .{ context.CS, context.DS, context.ES });
    serial.write.printf(messages.REG_FS_GS_SS, .{ context.FS, context.GS, context.SS });
    serial.write.printf("\n", .{});
}
