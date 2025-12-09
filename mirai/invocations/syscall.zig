//! SYSCALL/SYSRET implementation - Invocation mechanism using MSRs (Model Specific Registers)

const gdt = @import("../boot/gdt.zig");
const serial = @import("../drivers/serial.zig");
const tss = @import("../boot/tss.zig");

// MSR addresses
const IA32_STAR: u32 = 0xC0000081; // Segment selectors
const IA32_LSTAR: u32 = 0xC0000082; // Syscall entry point (64-bit)
const IA32_FMASK: u32 = 0xC0000084; // RFLAGS mask

pub fn init() void {
    serial.print("\n=== SYSCALL/SYSRET Setup ===\n");

    // Set up STAR - segment selectors for syscall/sysret
    // Bits 47:32 = Kernel CS base (syscall loads CS from this, SS from this+8)
    // Bits 63:48 = User CS base (sysret loads CS from this+16, SS from this+8)
    const star_value: u64 =
        (@as(u64, gdt.KERNEL_CODE) << 32) | // Kernel segments
        (@as(u64, gdt.USER_DATA) << 48); // User segments (base for +8 and +16)

    wrmsr(IA32_STAR, star_value);

    serial.print("STAR MSR: ");
    serial.print_hex(star_value);
    serial.print("\n");

    // Set up LSTAR - syscall entry point
    const entry_addr = @intFromPtr(&syscall_entry_asm);
    wrmsr(IA32_LSTAR, entry_addr);

    serial.print("LSTAR (entry point): ");
    serial.print_hex(entry_addr);
    serial.print("\n");

    // Set up FMASK - mask these RFLAGS bits on syscall entry
    // We mask IF (interrupts) - they'll be re-enabled after we're ready
    const fmask: u64 = 0x200; // IF flag
    wrmsr(IA32_FMASK, fmask);

    serial.print("FMASK: ");
    serial.print_hex(fmask);
    serial.print("\n");

    // Enable SYSCALL/SYSRET (SCE bit in EFER MSR)
    const IA32_EFER: u32 = 0xC0000080;
    const efer = rdmsr(IA32_EFER);
    wrmsr(IA32_EFER, efer | (1 << 0)); // Set SCE (System Call Extensions)

    serial.print("SYSCALL/SYSRET enabled\n");
}

// Write to MSR
fn wrmsr(msr: u32, value: u64) void {
    const low: u32 = @truncate(value);
    const high: u32 = @truncate(value >> 32);

    asm volatile (
        \\wrmsr
        :
        : [msr] "{ecx}" (msr),
          [low] "{eax}" (low),
          [high] "{edx}" (high),
    );
}

// Read from MSR
fn rdmsr(msr: u32) u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;

    asm volatile (
        \\rdmsr
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
        : [msr] "{ecx}" (msr),
    );

    return (@as(u64, high) << 32) | low;
}

// Assembly syscall entry point
comptime {
    asm (
        \\.global syscall_entry_asm
        \\syscall_entry_asm:
        \\  # SYSCALL has already:
        \\  #   - Saved RIP to RCX
        \\  #   - Saved RFLAGS to R11
        \\  #   - Loaded CS/SS from STAR
        \\  #   - Jumped here (LSTAR)
        \\  #   - Masked RFLAGS per FMASK
        \\  #
        \\  # We need to:
        \\  #   - Save user RSP
        \\  #   - Switch to kernel stack (from TSS)
        \\  #   - Save all registers
        \\  #   - Call handler
        \\  #   - Restore registers
        \\  #   - Use sysret to return
        \\
        \\  # Save user RSP to R15 temporarily
        \\  mov %rsp, %r15
        \\
        \\  # Get kernel stack from TSS
        \\  call get_kernel_stack
        \\  mov %rax, %rsp
        \\
        \\  # Build invocation context on kernel stack
        \\  push %r15              # User RSP
        \\  push %r11              # User RFLAGS (saved by syscall)
        \\  push $0x23              # User SS (USER_DATA | 3)
        \\  push %rcx              # User RIP (saved by syscall)
        \\  push $0x2B              # User CS (USER_CODE | 3)
        \\
        \\  # Push all registers
        \\  push %r15
        \\  push %r14
        \\  push %r13
        \\  push %r12
        \\  push %r11
        \\  push %r10
        \\  push %r9
        \\  push %r8
        \\  push %rbp
        \\  push %rdi
        \\  push %rsi
        \\  push %rdx
        \\  push %rcx
        \\  push %rbx
        \\  push %rax
        \\
        \\  # Re-enable interrupts (we're on kernel stack now)
        \\  sti
        \\
        \\  # Call invocation handler
        \\  mov %rsp, %rdi        # Pass context pointer
        \\  call handle_syscall
        \\
        \\  # Disable interrupts before returning to user
        \\  cli
        \\
        \\  # Restore registers (RAX might be modified with return value)
        \\  pop %rax
        \\  pop %rbx
        \\  pop %rcx
        \\  pop %rdx
        \\  pop %rsi
        \\  pop %rdi
        \\  pop %rbp
        \\  pop %r8
        \\  pop %r9
        \\  pop %r10
        \\  pop %r11
        \\  pop %r12
        \\  pop %r13
        \\  pop %r14
        \\  pop %r15
        \\
        \\  # Pop saved context
        \\  add $8, %rsp           # Skip user CS (sysret will set it)
        \\  pop %rcx               # User RIP for sysret
        \\  add $8, %rsp           # Skip user SS (sysret will set it)
        \\  pop %r11               # User RFLAGS for sysret
        \\  pop %rsp               # Restore user RSP
        \\
        \\  # Return to userspace
        \\  sysretq
    );
}

extern fn syscall_entry_asm() void;

// Handler called from syscall_entry
export fn handle_syscall(ctx_ptr: u64) void {
    const handler = @import("handler.zig");

    // Cast stack pointer to context
    const regs = @as(*SyscallContext, @ptrFromInt(ctx_ptr));

    // Build invocation context
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

    // Handle the invocation
    handler.handle_invocation(&inv_ctx);

    // Write back return value (RAX)
    regs.rax = inv_ctx.rax;
}

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

// Export for assembly to call - gets kernel stack from TSS
export fn get_kernel_stack() u64 {
    return tss.get_kernel_stack();
}
