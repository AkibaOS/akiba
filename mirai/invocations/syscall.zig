//! SYSCALL/SYSRET implementation - Invocation mechanism using MSRs

const entry = @import("../asm/entry.zig");
const gdt = @import("../boot/gdt.zig");
const handler = @import("handler.zig");
const msr = @import("../asm/msr.zig");
const serial = @import("../drivers/serial.zig");
const tss = @import("../boot/tss.zig");

// MSR addresses
const IA32_STAR: u32 = 0xC0000081;
const IA32_LSTAR: u32 = 0xC0000082;
const IA32_FMASK: u32 = 0xC0000084;
const IA32_EFER: u32 = 0xC0000080;

// Context saved on kernel stack
const SyscallContext = packed struct {
    rax: u64,
    rbx: u64,
    rcx: u64,
    rdx: u64,
    rsi: u64,
    rdi: u64,
    rbp: u64,
    r8: u64,
    r9: u64,
    r10: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,
    user_cs: u64,
    user_rip: u64,
    user_ss: u64,
    user_rflags: u64,
    user_rsp: u64,
};

pub fn init() void {
    // STAR: Segment selectors
    // Bits 47:32 = Kernel CS (SYSCALL loads this)
    // Bits 63:48 = User base selector (SYSRET adds 16 for CS, 8 for SS)
    const user_base = gdt.USER_CODE - 16;
    const star_value: u64 =
        (@as(u64, gdt.KERNEL_CODE) << 32) |
        (@as(u64, user_base) << 48);
    msr.write_msr(IA32_STAR, star_value);

    // LSTAR: Syscall entry point
    msr.write_msr(IA32_LSTAR, entry.get_entry_address());

    // FMASK: Mask interrupts during syscall entry
    msr.write_msr(IA32_FMASK, 0x200);

    // Enable SYSCALL/SYSRET in EFER
    const efer = msr.read_msr(IA32_EFER);
    msr.write_msr(IA32_EFER, efer | (1 << 0));
}

// Handler called from syscall entry assembly
export fn handle_syscall(ctx_ptr: u64) void {
    const regs = @as(*SyscallContext, @ptrFromInt(ctx_ptr));

    var inv_ctx = handler.InvocationContext{
        .rax = regs.rax,
        .rbx = regs.rbx,
        .rcx = regs.rcx,
        .rdx = regs.rdx,
        .rsi = regs.rsi,
        .rdi = regs.rdi,
        .rbp = regs.rbp,
        .rsp = regs.user_rsp,
        .r8 = regs.r8,
        .r9 = regs.r9,
        .r10 = regs.r10,
        .r11 = regs.r11,
        .r12 = regs.r12,
        .r13 = regs.r13,
        .r14 = regs.r14,
        .r15 = regs.r15,
        .rip = regs.user_rip,
        .rflags = regs.user_rflags,
        .cs = regs.user_cs,
        .ss = regs.user_ss,
    };

    handler.handle_invocation(&inv_ctx);
    regs.rax = inv_ctx.rax;
}

// Export for assembly to call
export fn get_kernel_stack() u64 {
    return tss.get_kernel_stack();
}
