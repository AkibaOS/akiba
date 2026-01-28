//! System Call Operations
//! Wrappers for userspace-kernel communication

/// Invoke system call with up to 6 parameters
/// Always sets all 6 parameter registers (unused ones are zero)
pub inline fn invoke_syscall(
    number: u64,
    param0: u64,
    param1: u64,
    param2: u64,
    param3: u64,
    param4: u64,
    param5: u64,
) u64 {
    var result: u64 = undefined;
    asm volatile ("syscall"
        : [ret] "={rax}" (result),
        : [num] "{rax}" (number),
          [p0] "{rdi}" (param0),
          [p1] "{rsi}" (param1),
          [p2] "{rdx}" (param2),
          [p3] "{r10}" (param3),
          [p4] "{r8}" (param4),
          [p5] "{r9}" (param5),
        : .{ .rcx = true, .r11 = true, .memory = true }
    );
    return result;
}
