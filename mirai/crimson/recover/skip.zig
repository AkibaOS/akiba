//! Skip Faulting Instruction

const constants = @import("mirai").crimson.constants;
const types = @import("mirai").crimson.types;

const opcodes = constants.opcodes;

const Exception = types.exception.Exception;

pub fn skipInstruction(exception: *Exception) bool {
    const instruction_length = getInstructionLength(exception.Frame.RIP);
    if (instruction_length == 0) {
        return false;
    }

    exception.Frame.RIP += instruction_length;
    return true;
}

fn getInstructionLength(rip: u64) u64 {
    const code_pointer: [*]const u8 = @ptrFromInt(rip);
    const first_byte = code_pointer[0];

    if (first_byte == opcodes.OPCODE_BREAKPOINT) return 1;
    if (first_byte == opcodes.OPCODE_INTERRUPT_IMMEDIATE) return 2;
    if (first_byte == opcodes.OPCODE_HALT) return 1;
    if (first_byte == opcodes.OPCODE_NOP) return 1;

    return 1;
}

pub fn canSkip(exception: *const Exception) bool {
    return exception.Recoverable and exception.Frame.RIP != 0;
}
