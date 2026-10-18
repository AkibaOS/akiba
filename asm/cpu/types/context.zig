//! Cooperative CPU Context Type

const control = @import("asm").cpu.constants.control;
const fpu = @import("asm").cpu.constants.fpu;
const strings = @import("asm").cpu.strings.context;

pub const Context = extern struct {
    RAX: u64 = 0,
    RBX: u64 = 0,
    RCX: u64 = 0,
    RDX: u64 = 0,
    RSI: u64 = 0,
    RDI: u64 = 0,
    RBP: u64 = 0,
    R8: u64 = 0,
    R9: u64 = 0,
    R10: u64 = 0,
    R11: u64 = 0,
    R12: u64 = 0,
    R13: u64 = 0,
    R14: u64 = 0,
    R15: u64 = 0,
    RSP: u64 = 0,
    RIP: u64 = 0,
    RFLAGS: u64 = control.RFLAGS_RESERVED,
    CR3: u64 = 0,
    FPU: [fpu.STATE_SIZE]u8 align(fpu.STATE_ALIGNMENT) = [_]u8{0} ** fpu.STATE_SIZE,
};

pub const Transfer = *const fn (*Context, *const Context) callconv(.{ .x86_64_sysv = .{} }) void;

comptime {
    if (@alignOf(Context) < fpu.STATE_ALIGNMENT or @offsetOf(Context, "FPU") % fpu.STATE_ALIGNMENT != 0 or
        @sizeOf(Context) != @offsetOf(Context, "FPU") + fpu.STATE_SIZE) @compileError(strings.INVALID_LAYOUT);
}
