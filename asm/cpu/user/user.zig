//! Ring Three CPU Transfers

const std = @import("std");

const constants = @import("asm").cpu.constants;
const halt = @import("asm").cpu.halt;
const layout = @import("common").constants.memory.layout;
const strings = @import("asm").cpu.strings.user;
const types = @import("asm").cpu.types.user;

pub fn enter(entry: *const types.Entry) noreturn {
    if (entry.RIP == 0 or entry.RIP > layout.USER_SPACE_END or
        entry.RSP == 0 or entry.RSP > layout.USER_SPACE_END or
        (entry.RSP & (constants.user.STACK_ALIGNMENT - 1)) != 0 or
        entry.RFLAGS != constants.user.RFLAGS_INITIAL or
        !isUserSelector(entry.CS) or !isUserSelector(entry.SS)) halt.haltLoop();
    const fpu_end = entry.FPUAddress +% (constants.fpu.STATE_SIZE - 1);
    if (entry.FPUAddress == 0 or
        (entry.FPUAddress & (constants.fpu.STATE_ALIGNMENT - 1)) != 0 or
        fpu_end < entry.FPUAddress or
        !isCanonical(entry.FPUAddress) or !isCanonical(fpu_end)) halt.haltLoop();
    asm volatile (entryInstructions()
        :
        : [entry] "{rdi}" (@intFromPtr(entry)),
        : .{ .memory = true });
    unreachable;
}

pub fn resumeKernel(stack_top: u64, continuation: types.Continuation, context: *anyopaque) noreturn {
    if (stack_top < ~layout.USER_SPACE_END or
        (stack_top & (constants.user.STACK_ALIGNMENT - 1)) != 0) halt.haltLoop();
    asm volatile (strings.RESUME_KERNEL
        :
        : [stack] "{rdi}" (stack_top),
          [continuation] "{rsi}" (@intFromPtr(continuation)),
          [context] "{rdx}" (@intFromPtr(context)),
        : .{ .memory = true });
    unreachable;
}

fn entryInstructions() []const u8 {
    comptime var offsets: []const u8 = strings.EMPTY;
    inline for (@typeInfo(types.Entry).@"struct".fields) |field| {
        offsets = offsets ++ std.fmt.comptimePrint(strings.OFFSET_FORMAT, .{ field.name, @offsetOf(types.Entry, field.name) });
    }
    return offsets ++ strings.ENTER;
}

fn isCanonical(address: u64) bool {
    return address <= layout.USER_SPACE_END or address >= ~layout.USER_SPACE_END;
}

fn isUserSelector(selector: u64) bool {
    return selector > constants.user.SELECTOR_RPL_MASK and selector <= constants.user.SELECTOR_MAX and
        (selector & constants.user.SELECTOR_RPL_MASK) == constants.user.SELECTOR_RPL_USER;
}
