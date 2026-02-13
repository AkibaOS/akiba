//! System Call Entry Point
//! Assembly stub for handling SYSCALL instruction from userspace

// External handlers
extern fn handle_syscall(ctx: u64) void;
extern fn get_kernel_stack() u64;

/// Address of syscall entry point for LSTAR MSR
pub fn get_entry_address() u64 {
    return @intFromPtr(&syscall_entry_asm);
}

extern fn syscall_entry_asm() void;

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
