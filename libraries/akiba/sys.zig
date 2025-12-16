//! Low-level syscall interface

pub const Invocation = enum(u64) {
    exit = 0x01,
    attach = 0x02,
    seal = 0x03,
    view = 0x04,
    mark = 0x05,
};

pub fn syscall1(inv: Invocation, arg1: u64) u64 {
    return asm volatile (
        \\syscall
        : [ret] "={rax}" (-> u64),
        : [inv] "{rax}" (@intFromEnum(inv)),
          [arg1] "{rdi}" (arg1),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall2(inv: Invocation, arg1: u64, arg2: u64) u64 {
    return asm volatile (
        \\syscall
        : [ret] "={rax}" (-> u64),
        : [inv] "{rax}" (@intFromEnum(inv)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall3(inv: Invocation, arg1: u64, arg2: u64, arg3: u64) u64 {
    return asm volatile (
        \\syscall
        : [ret] "={rax}" (-> u64),
        : [inv] "{rax}" (@intFromEnum(inv)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
        : .{ .rcx = true, .r11 = true, .memory = true });
}
