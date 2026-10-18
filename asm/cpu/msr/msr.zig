//! Model Specific Register Operations

const constants = @import("asm").cpu.constants;
const cpuid = @import("asm").cpu.cpuid;
const strings = @import("asm").cpu.strings.msr;

const registers = constants.msr;

pub fn read(register: u32) u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile (strings.READ_REGISTER
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
        : [register] "{ecx}" (register),
        : .{ .memory = true });
    return (@as(u64, high) << @bitSizeOf(u32)) | low;
}

pub fn write(register: u32, value: u64) void {
    asm volatile (strings.WRITE_REGISTER
        :
        : [register] "{ecx}" (register),
          [low] "{eax}" (@as(u32, @truncate(value))),
          [high] "{edx}" (@as(u32, @truncate(value >> @bitSizeOf(u32)))),
        : .{ .memory = true });
}

pub fn validateMemoryTypes() bool {
    if (!cpuid.supportsPageAttributeTable()) return false;
    const memory_types = read(registers.PAT);
    return (memory_types & registers.PAT_ENTRY_MASK) == registers.PAT_WRITE_BACK and
        ((memory_types >> registers.PAT_FRAMEBUFFER_SHIFT) & registers.PAT_ENTRY_MASK) == registers.PAT_UNCACHEABLE;
}

pub fn enableNoExecute() bool {
    if (!cpuid.supportsNoExecute()) return false;
    write(registers.EFER, read(registers.EFER) | registers.EFER_NO_EXECUTE_ENABLE);
    return (read(registers.EFER) & registers.EFER_NO_EXECUTE_ENABLE) != 0;
}
