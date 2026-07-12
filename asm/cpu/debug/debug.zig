//! Debug Register Operations

pub fn readDR0() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr0, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDR1() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr1, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDR2() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr2, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDR3() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr3, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDR6() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr6, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readDR7() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr7, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn writeDR0(value: u64) void {
    asm volatile ("mov %[value], %%dr0"
        :
        : [value] "r" (value),
    );
}

pub fn writeDR1(value: u64) void {
    asm volatile ("mov %[value], %%dr1"
        :
        : [value] "r" (value),
    );
}

pub fn writeDR2(value: u64) void {
    asm volatile ("mov %[value], %%dr2"
        :
        : [value] "r" (value),
    );
}

pub fn writeDR3(value: u64) void {
    asm volatile ("mov %[value], %%dr3"
        :
        : [value] "r" (value),
    );
}

pub fn writeDR6(value: u64) void {
    asm volatile ("mov %[value], %%dr6"
        :
        : [value] "r" (value),
    );
}

pub fn writeDR7(value: u64) void {
    asm volatile ("mov %[value], %%dr7"
        :
        : [value] "r" (value),
    );
}

pub fn clearDR6() void {
    writeDR6(0);
}