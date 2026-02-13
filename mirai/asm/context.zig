//! Context Switching Operations
//! Low-level assembly for switching between Kata execution contexts

const kata_mod = @import("../kata/kata.zig");

/// Switch to a Kata's execution context
/// This function never returns - it jumps to userspace via iretq
pub fn switch_to_context(ctx: *const kata_mod.Context, page_table: u64, kernel_stack: u64) noreturn {
    const ctx_addr = @intFromPtr(ctx);

    asm volatile (
    // Load context address and page table into registers
        \\mov %[ctx_addr], %%rdi
        \\mov %[pt], %%rsi
        \\
        // Switch to kata's higher-half kernel stack
        \\mov %[kstack], %%rsp
        \\
        // Read iretq frame values from context struct
        // Offsets based on Context struct layout:
        //   rsp=56, rip=128, rflags=136, cs=144, ss=152
        \\mov 152(%%rdi), %%r12
        \\mov 56(%%rdi), %%r13
        \\mov 136(%%rdi), %%r14
        \\mov 144(%%rdi), %%r15
        \\mov 128(%%rdi), %%rax
        \\
        // Build iretq frame (ss, rsp, rflags, cs, rip)
        \\pushq %%r12
        \\pushq %%r13
        \\pushq %%r14
        \\pushq %%r15
        \\pushq %%rax
        \\
        // Switch to user page table
        \\mov %%rsi, %%cr3
        \\
        // Restore registers from context (offsets from Context struct)
        // rax=0, rbx=8, rcx=16, rdx=24, rsi=32, rdi=40, rbp=48
        // r8=64, r9=72, r10=80, r11=88, r12=96, r13=104, r14=112, r15=120
        \\mov 8(%%rdi), %%rbx
        \\mov 16(%%rdi), %%rcx
        \\mov 24(%%rdi), %%rdx
        \\mov 32(%%rdi), %%rsi
        \\mov 48(%%rdi), %%rbp
        \\mov 64(%%rdi), %%r8
        \\mov 72(%%rdi), %%r9
        \\mov 80(%%rdi), %%r10
        \\mov 88(%%rdi), %%r11
        \\mov 96(%%rdi), %%r12
        \\mov 104(%%rdi), %%r13
        \\mov 112(%%rdi), %%r14
        \\mov 120(%%rdi), %%r15
        \\mov 0(%%rdi), %%rax
        \\mov 40(%%rdi), %%rdi
        \\
        // Jump to userspace
        \\iretq
        :
        : [ctx_addr] "r" (ctx_addr),
          [pt] "r" (page_table),
          [kstack] "r" (kernel_stack),
        : .{ .memory = true }
    );
    unreachable;
}
