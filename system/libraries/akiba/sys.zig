//! Low-level syscall interface

pub const Invocation = enum(u64) {
    exit = 0x01,
    attach = 0x02,
    seal = 0x03,
    view = 0x04,
    mark = 0x05,
    spawn = 0x06,
    wait = 0x07,
    yield = 0x08,
    getkeychar = 0x09,
};

pub fn syscall0(inv: Invocation) u64 {
    var result: u64 = undefined;
    asm volatile ("syscall"
        : [ret] "={rax}" (result),
        : [inv] "{rax}" (@intFromEnum(inv)),
        : .{ .rcx = true, .r11 = true, .memory = true });
    return result;
}

pub fn syscall1(inv: Invocation, arg1: u64) u64 {
    var result: u64 = undefined;
    asm volatile ("syscall"
        : [ret] "={rax}" (result),
        : [inv] "{rax}" (@intFromEnum(inv)),
          [arg1] "{rdi}" (arg1),
        : .{ .rcx = true, .r11 = true, .memory = true });
    return result;
}

pub fn syscall2(inv: Invocation, arg1: u64, arg2: u64) u64 {
    var result: u64 = undefined;
    asm volatile ("syscall"
        : [ret] "={rax}" (result),
        : [inv] "{rax}" (@intFromEnum(inv)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
        : .{ .rcx = true, .r11 = true, .memory = true });
    return result;
}

pub fn syscall3(inv: Invocation, arg1: u64, arg2: u64, arg3: u64) u64 {
    var result: u64 = undefined;
    asm volatile ("syscall"
        : [ret] "={rax}" (result),
        : [inv] "{rax}" (@intFromEnum(inv)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
        : .{ .rcx = true, .r11 = true, .memory = true });
    return result;
}
