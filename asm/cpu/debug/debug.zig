//! Debug Register Operations

const strings = @import("asm").cpu.strings.debug;

pub fn readDR0() u64 {
    var value: u64 = undefined;
    asm volatile (strings.READ_DR0
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDR1() u64 {
    var value: u64 = undefined;
    asm volatile (strings.READ_DR1
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDR2() u64 {
    var value: u64 = undefined;
    asm volatile (strings.READ_DR2
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDR3() u64 {
    var value: u64 = undefined;
    asm volatile (strings.READ_DR3
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDR6() u64 {
    var value: u64 = undefined;
    asm volatile (strings.READ_DR6
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDR7() u64 {
    var value: u64 = undefined;
    asm volatile (strings.READ_DR7
        : [value] "=r" (value),
    );
    return value;
}

pub fn writeDR0(value: u64) void {
    asm volatile (strings.WRITE_DR0
        :
        : [value] "r" (value),
    );
}

pub fn writeDR1(value: u64) void {
    asm volatile (strings.WRITE_DR1
        :
        : [value] "r" (value),
    );
}

pub fn writeDR2(value: u64) void {
    asm volatile (strings.WRITE_DR2
        :
        : [value] "r" (value),
    );
}

pub fn writeDR3(value: u64) void {
    asm volatile (strings.WRITE_DR3
        :
        : [value] "r" (value),
    );
}

pub fn writeDR6(value: u64) void {
    asm volatile (strings.WRITE_DR6
        :
        : [value] "r" (value),
    );
}

pub fn writeDR7(value: u64) void {
    asm volatile (strings.WRITE_DR7
        :
        : [value] "r" (value),
    );
}

pub fn clearDR6() void {
    writeDR6(0);
}
