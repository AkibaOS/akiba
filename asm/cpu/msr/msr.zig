//! Model Specific Register Operations

const constants = @import("asm").cpu.constants;

const registers = constants.msr;

pub fn read(register: u32) u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdmsr"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
        : [register] "{ecx}" (register),
    );
    return (@as(u64, high) << @bitSizeOf(u32)) | low;
}

pub fn write(register: u32, value: u64) void {
    asm volatile ("wrmsr"
        :
        : [register] "{ecx}" (register),
          [low] "{eax}" (@as(u32, @truncate(value))),
          [high] "{edx}" (@as(u32, @truncate(value >> @bitSizeOf(u32)))),
    );
}

pub fn enableNoExecute() bool {
    write(registers.EFER, read(registers.EFER) | registers.EFER_NO_EXECUTE_ENABLE);
    return (read(registers.EFER) & registers.EFER_NO_EXECUTE_ENABLE) != 0;
}
