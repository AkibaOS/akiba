//! Context Shifting - Save and restore Kata execution state
//! Shifts between different Kata, preserving their execution context

const kata_mod = @import("kata.zig");
const gdt = @import("../boot/gdt.zig");
const tss = @import("../boot/tss.zig");
const serial = @import("../drivers/serial.zig");

const Kata = kata_mod.Kata;
const Context = kata_mod.Context;

// Current executing Kata (for saving context on interrupts)
var current_context: ?*Context = null;

pub fn init() void {
    serial.print("\n=== Context Shifting ===\n");
    serial.print("Shift mechanism initialized\n");
}

// Shift to a new Kata
pub fn shift_to_kata(target_kata: *Kata) void {
    // Update TSS kernel stack for this Kata
    tss.set_kernel_stack(target_kata.stack_top);

    // Switch to Kata's page table
    set_page_table(target_kata.page_table);

    // Set current context pointer (for saving on interrupts)
    current_context = &target_kata.context;

    // Perform the actual context shift
    shift_context(&target_kata.context);
}

// Save current context (called from interrupt handlers)
pub fn save_current_context(int_context: *const InterruptContext) void {
    if (current_context) |ctx| {
        ctx.rax = int_context.rax;
        ctx.rbx = int_context.rbx;
        ctx.rcx = int_context.rcx;
        ctx.rdx = int_context.rdx;
        ctx.rsi = int_context.rsi;
        ctx.rdi = int_context.rdi;
        ctx.rbp = int_context.rbp;
        ctx.rsp = int_context.rsp;
        ctx.r8 = int_context.r8;
        ctx.r9 = int_context.r9;
        ctx.r10 = int_context.r10;
        ctx.r11 = int_context.r11;
        ctx.r12 = int_context.r12;
        ctx.r13 = int_context.r13;
        ctx.r14 = int_context.r14;
        ctx.r15 = int_context.r15;
        ctx.rip = int_context.rip;
        ctx.rflags = int_context.rflags;
        ctx.cs = int_context.cs;
        ctx.ss = int_context.ss;
    }
}

// Interrupt context (matches interrupt stack frame)
pub const InterruptContext = packed struct {
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rbp: u64,
    rdi: u64,
    rsi: u64,
    rdx: u64,
    rcx: u64,
    rbx: u64,
    rax: u64,
    int_num: u64,
    error_code: u64,
    rip: u64,
    cs: u64,
    rflags: u64,
    rsp: u64,
    ss: u64,
};

// Low-level context shift (assembly)
fn shift_context(ctx: *const Context) void {
    asm volatile (
        \\# Restore general purpose registers
        \\mov %[rax], %%rax
        \\mov %[rbx], %%rbx
        \\mov %[rcx], %%rcx
        \\mov %[rdx], %%rdx
        \\mov %[rsi], %%rsi
        \\mov %[rdi], %%rdi
        \\mov %[r8], %%r8
        \\mov %[r9], %%r9
        \\mov %[r10], %%r10
        \\mov %[r11], %%r11
        \\mov %[r12], %%r12
        \\mov %[r13], %%r13
        \\mov %[r14], %%r14
        \\mov %[r15], %%r15
        \\
        \\# Restore RBP last (after using it to access context)
        \\mov %[rbp], %%rbp
        \\
        \\# Build iretq frame on stack
        \\pushq %[ss]
        \\pushq %[rsp]
        \\pushq %[rflags]
        \\pushq %[cs]
        \\pushq %[rip]
        \\
        \\# Jump to Kata
        \\iretq
        :
        : [rax] "m" (ctx.rax),
          [rbx] "m" (ctx.rbx),
          [rcx] "m" (ctx.rcx),
          [rdx] "m" (ctx.rdx),
          [rsi] "m" (ctx.rsi),
          [rdi] "m" (ctx.rdi),
          [rbp] "m" (ctx.rbp),
          [rsp] "m" (ctx.rsp),
          [r8] "m" (ctx.r8),
          [r9] "m" (ctx.r9),
          [r10] "m" (ctx.r10),
          [r11] "m" (ctx.r11),
          [r12] "m" (ctx.r12),
          [r13] "m" (ctx.r13),
          [r14] "m" (ctx.r14),
          [r15] "m" (ctx.r15),
          [rip] "m" (ctx.rip),
          [rflags] "m" (ctx.rflags),
          [cs] "m" (ctx.cs),
          [ss] "m" (ctx.ss),
        : .{ .memory = true });
    unreachable;
}

fn set_page_table(page_table_phys: u64) void {
    asm volatile ("mov %[pt], %%cr3"
        :
        : [pt] "r" (page_table_phys),
        : .{ .memory = true });
}
