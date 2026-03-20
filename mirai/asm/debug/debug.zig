//! Debug Register Operations

pub fn read_dr0() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr0, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn read_dr1() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr1, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn read_dr2() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr2, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn read_dr3() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr3, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn read_dr6() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr6, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn read_dr7() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%dr7, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn write_dr0(value: u64) void {
    asm volatile ("mov %[value], %%dr0"
        :
        : [value] "r" (value),
    );
}

pub fn write_dr1(value: u64) void {
    asm volatile ("mov %[value], %%dr1"
        :
        : [value] "r" (value),
    );
}

pub fn write_dr2(value: u64) void {
    asm volatile ("mov %[value], %%dr2"
        :
        : [value] "r" (value),
    );
}

pub fn write_dr3(value: u64) void {
    asm volatile ("mov %[value], %%dr3"
        :
        : [value] "r" (value),
    );
}

pub fn write_dr6(value: u64) void {
    asm volatile ("mov %[value], %%dr6"
        :
        : [value] "r" (value),
    );
}

pub fn write_dr7(value: u64) void {
    asm volatile ("mov %[value], %%dr7"
        :
        : [value] "r" (value),
    );
}

pub fn clear_dr6() void {
    write_dr6(0);
}
