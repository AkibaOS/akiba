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
        // Zero all registers for clean userspace entry
        \\xor %%rax, %%rax
        \\xor %%rbx, %%rbx
        \\xor %%rcx, %%rcx
        \\xor %%rdx, %%rdx
        \\xor %%rsi, %%rsi
        \\xor %%rdi, %%rdi
        \\xor %%rbp, %%rbp
        \\xor %%r8, %%r8
        \\xor %%r9, %%r9
        \\xor %%r10, %%r10
        \\xor %%r11, %%r11
        \\xor %%r12, %%r12
        \\xor %%r13, %%r13
        \\xor %%r14, %%r14
        \\xor %%r15, %%r15
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
