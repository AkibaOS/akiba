//! Skip Faulting Instruction

const types = @import("../types/types.zig");

const Exception = types.Exception;
const Frame = types.Frame;

pub fn skip_instruction(exception: *Exception) bool {
    const instruction_length = get_instruction_length(exception.frame.rip);
    if (instruction_length == 0) {
        return false;
    }

    exception.frame.rip += instruction_length;
    return true;
}

fn get_instruction_length(rip: u64) u64 {
    const code_ptr: [*]const u8 = @ptrFromInt(rip);
    const first_byte = code_ptr[0];

    if (first_byte == 0xCC) return 1;
    if (first_byte == 0xCD) return 2;
    if (first_byte == 0xF4) return 1;
    if (first_byte == 0x90) return 1;

    return 1;
}

pub fn can_skip(exception: *const Exception) bool {
    return exception.recoverable and exception.frame.rip != 0;
}
