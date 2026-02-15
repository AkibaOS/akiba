//! SYSCALL/SYSRET implementation - Invocation mechanism using MSRs

const entry = @import("../asm/entry.zig");
const gdt = @import("../boot/gdt.zig");
const handler = @import("handler.zig");
const int = @import("../utils/types/int.zig");
const msr_const = @import("../common/constants/msr.zig");
const msr = @import("../asm/msr.zig");
const ptr = @import("../utils/types/ptr.zig");
const tss = @import("../boot/tss.zig");

const SYSRET_USER_BASE_OFFSET: u64 = 16;

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
    const kernel_cs = int.u64_of(gdt.KERNEL_CODE);
    const user_base = int.u64_of(gdt.USER_CODE) - SYSRET_USER_BASE_OFFSET;

    const star_value =
        (kernel_cs << msr_const.STAR_KERNEL_CS_SHIFT) |
        (user_base << msr_const.STAR_USER_BASE_SHIFT);

    msr.write(msr_const.IA32_STAR, star_value);
    msr.write(msr_const.IA32_LSTAR, entry.get_entry_address());
    msr.write(msr_const.IA32_FMASK, msr_const.FMASK_IF);

    const efer = msr.read(msr_const.IA32_EFER);
    msr.write(msr_const.IA32_EFER, efer | msr_const.EFER_SCE);
}

export fn handle_syscall(ctx_ptr: u64) void {
    const regs = ptr.of(SyscallContext, ctx_ptr);

    var ctx = handler.InvocationContext{
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

    handler.handle(&ctx);
    regs.rax = ctx.rax;
}

export fn get_kernel_stack() u64 {
    return tss.get_kernel_stack();
}
