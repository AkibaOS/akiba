//! Dump Context for Debugging

const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const messages = strings.messages;

const Context = types.context.Context;

pub fn dumpContext(context: *const Context) void {
    serial.write.printf(messages.DUMP_REGISTERS_GENERAL_1, .{ context.RAX, context.RBX, context.RCX, context.RDX });
    serial.write.printf(messages.DUMP_REGISTERS_GENERAL_2, .{ context.RSI, context.RDI, context.RBP, context.RSP });
    serial.write.printf(messages.DUMP_REGISTERS_GENERAL_3, .{ context.R8, context.R9, context.R10, context.R11 });
    serial.write.printf(messages.DUMP_REGISTERS_GENERAL_4, .{ context.R12, context.R13, context.R14, context.R15 });
    serial.write.printf(messages.DUMP_REGISTERS_INSTRUCTION, .{ context.RIP, context.RFLAGS });
    serial.write.printf(messages.DUMP_REGISTERS_CONTROL, .{ context.CR0, context.CR2, context.CR3, context.CR4 });
}
