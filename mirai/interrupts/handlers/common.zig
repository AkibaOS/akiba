//! Common Interrupt Entry/Exit

pub const InterruptFrame = extern struct {
    R15: u64,
    R14: u64,
    R13: u64,
    R12: u64,
    R11: u64,
    R10: u64,
    R9: u64,
    R8: u64,
    RBP: u64,
    RDI: u64,
    RSI: u64,
    RDX: u64,
    RCX: u64,
    RBX: u64,
    RAX: u64,
    Vector: u64,
    ErrorCode: u64,
    RIP: u64,
    CS: u64,
    RFLAGS: u64,
    RSP: u64,
    SS: u64,
};

comptime {
    if (@sizeOf(InterruptFrame) != 22 * @sizeOf(u64)) @compileError("InterruptFrame size mismatch");
}
