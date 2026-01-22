//! SYSCALL/SYSRET implementation - Invocation mechanism using MSRs (Model Specific Registers)

const gdt = @import("../boot/gdt.zig");
const serial = @import("../drivers/serial.zig");
const handler = @import("handler.zig");
const tss = @import("../boot/tss.zig");

// MSR addresses
const IA32_STAR: u32 = 0xC0000081; // Segment selectors
const IA32_LSTAR: u32 = 0xC0000082; // Syscall entry point (64-bit)
const IA32_FMASK: u32 = 0xC0000084; // RFLAGS mask

pub fn init() void {
    serial.print("\n=== SYSCALL/SYSRET Setup ===\n");

    // STAR: Segment selectors (Kernel CS/SS at 47:32, User CS/SS at 63:48)
    const star_value: u64 =
        (@as(u64, gdt.KERNEL_CODE) << 32) |
        (@as(u64, gdt.USER_DATA) << 48);
    wrmsr(IA32_STAR, star_value);

    // LSTAR: Syscall entry point
    const entry_addr = @intFromPtr(&syscall_entry_asm);
    wrmsr(IA32_LSTAR, entry_addr);

    // FMASK: Mask interrupts during syscall entry
    const fmask: u64 = 0x200;
    wrmsr(IA32_FMASK, fmask);

    // Enable SYSCALL/SYSRET in EFER
    const IA32_EFER: u32 = 0xC0000080;
    const efer = rdmsr(IA32_EFER);
    wrmsr(IA32_EFER, efer | (1 << 0));

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
        \\  # At entry: RCX = user RIP, R11 = user RFLAGS, RSP = user RSP, RAX = syscall#
        \\  
        \\  # Strategy: Use SWAPGS-like approach but with stack
        \\  # Save everything on user stack, switch to kernel stack, copy over
        \\  
        \\  # First, save user RSP by pushing all regs then calculating
        \\  push %rax
        \\  push %rbx
        \\  push %rcx
        \\  push %rdx
        \\  push %rsi
        \\  push %rdi
        \\  push %rbp
        \\  push %r8
        \\  push %r9
        \\  push %r10
        \\  push %r11
        \\  push %r12
        \\  push %r13
        \\  push %r14
        \\  push %r15
        \\  
        \\  # Get kernel stack (returns in RAX, RSP unchanged after ret)
        \\  call get_kernel_stack
        \\  
        \\  # RAX now has kernel stack pointer
        \\  # RSP points to saved R15 (call/ret balanced)
        \\  mov %rsp, %r15         # R15 = pointer to saved registers
        \\  lea 120(%r15), %r14    # R14 = original user RSP (before 15 pushes)
        \\  mov %rax, %rsp         # Switch to kernel stack
        \\  
        \\  # Build struct on kernel stack by reading from user stack (via R15)
        \\  # User stack has (from low to high addr): [rax][rbx][rcx][rdx][rsi][rdi][rbp][r8-r15]
        \\  # We push in REVERSE order so struct layout matches (stack grows down)
        \\  # NOTE: RCX and R11 already have user_rip and user_rflags from SYSCALL!
        \\  push %r14              # user_rsp (last in struct, push first)
        \\  push %r11              # user_rflags (R11 saved by SYSCALL)
        \\  push $0x1B             # user_ss
        \\  push %rcx              # user_rip (RCX saved by SYSCALL)
        \\  push $0x23             # user_cs
        \\  push 0(%r15)           # r15
        \\  push 8(%r15)           # r14
        \\  push 16(%r15)          # r13
        \\  push 24(%r15)          # r12
        \\  push 32(%r15)          # r11 (value before syscall)
        \\  push 40(%r15)          # r10
        \\  push 48(%r15)          # r9
        \\  push 56(%r15)          # r8
        \\  push 64(%r15)          # rbp
        \\  push 72(%r15)          # rdi
        \\  push 80(%r15)          # rsi
        \\  push 88(%r15)          # rdx
        \\  push 96(%r15)          # rcx (value before syscall)
        \\  push 104(%r15)         # rbx
        \\  push 112(%r15)         # rax (first in struct, push last)
        \\
        \\  # Re-enable interrupts (we're on kernel stack now)
        \\  sti
        \\
        \\  # Call invocation handler
        \\  mov %rsp, %rdi        # Pass context pointer
        \\
        \\  # DEBUG: Check saved RIP before calling handler
        \\  push %rdi
        \\  mov 128(%rsp), %rdi
        \\  call debug_saved_rip
        \\  pop %rdi
        \\
        \\  # Call invocation handler
        \\  mov %rsp, %rdi        # Pass context pointer
        \\  call handle_syscall
        \\
        \\  # Disable interrupts before returning to user
        \\  cli
        \\
        \\  # Restore registers (RAX might be modified with return value)
        \\  # NOTE: Don't restore RCX and R11 - they're needed for sysret!
        \\  pop %rax
        \\  pop %rbx
        \\  add $8, %rsp           # Skip RCX (will be loaded from saved RIP)
        \\  pop %rdx
        \\  pop %rsi
        \\  pop %rdi
        \\  pop %rbp
        \\  pop %r8
        \\  pop %r9
        \\  pop %r10
        \\  add $8, %rsp           # Skip R11 (will be loaded from saved RFLAGS)
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

    // // DEBUG: Log what we're returning
    // serial.print("Syscall complete, returning to RIP: ");
    // serial.print_hex(regs.user_rip);
    // serial.print(", RAX: ");
    // serial.print_hex(regs.rax);
    // serial.print(", CR3: ");
    // const cr3 = asm volatile ("mov %%cr3, %[result]"
    //     : [result] "=r" (-> u64),
    // );
    // serial.print_hex(cr3);
    // serial.print("\n");
}

// Context saved on kernel stack
const SyscallContext = packed struct {
    rax: u64, // 0
    rbx: u64, // 8
    rcx: u64, // 16
    rdx: u64, // 24
    rsi: u64, // 32
    rdi: u64, // 40
    rbp: u64, // 48
    r8: u64, // 56
    r9: u64, // 64
    r10: u64, // 72
    r11: u64, // 80
    r12: u64, // 88
    r13: u64, // 96
    r14: u64, // 104
    r15: u64, // 112
    user_cs: u64, // 120
    user_rip: u64, // 128
    user_ss: u64, // 136
    user_rflags: u64, // 144
    user_rsp: u64, // 152
};

// Export for assembly to call - gets kernel stack from TSS
export fn get_kernel_stack() u64 {
    return tss.get_kernel_stack();
}

export fn debug_saved_rip(rip: u64) void {
    serial.print("Syscall entry: saved RIP = ");
    serial.print_hex(rip);
    serial.print("\n");
}
