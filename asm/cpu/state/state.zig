//! CPU State Operations

const strings = @import("asm").cpu.strings.state;

pub fn readStackPointer() u64 {
    var value: u64 = undefined;
    asm volatile (strings.READ_STACK_POINTER
        : [value] "=r" (value),
    );
    return value;
}

pub fn readBasePointer() u64 {
    var value: u64 = undefined;
    asm volatile (strings.READ_BASE_POINTER
        : [value] "=r" (value),
    );
    return value;
}

pub fn readFlags() u64 {
    var value: u64 = undefined;
    asm volatile (strings.READ_FLAGS
        : [value] "=r" (value),
    );
    return value;
}

pub fn readTimeStampCounter() u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile (strings.READ_TIME_STAMP_COUNTER
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
    );
    return (@as(u64, high) << 32) | low;
}

pub fn clearTaskSwitched() void {
    asm volatile (strings.CLEAR_TASK_SWITCHED ::: .{ .rax = true });
}
