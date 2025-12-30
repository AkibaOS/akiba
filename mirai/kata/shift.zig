//! Context Shifting - Save and restore Kata execution state

const kata_mod = @import("kata.zig");
const gdt = @import("../boot/gdt.zig");
const tss = @import("../boot/tss.zig");
const serial = @import("../drivers/serial.zig");

const Kata = kata_mod.Kata;
const Context = kata_mod.Context;

var current_context: ?*Context = null;

pub fn init() void {
    serial.print("\n=== Context Shifting ===\n");
    serial.print("Shift mechanism initialized\n");
}

pub fn shift_to_kata(target_kata: *Kata) void {
    serial.print("\n=== Context Shift ===\n");
    serial.print("Shifting to Kata ");
    serial.print_hex(target_kata.id);
    serial.print("\n");
    serial.print("  Entry: ");
    serial.print_hex(target_kata.context.rip);
    serial.print("\n  Stack: ");
    serial.print_hex(target_kata.context.rsp);
    serial.print("\n  CR3: ");
    serial.print_hex(target_kata.page_table);
    serial.print("\n");

    // Update TSS kernel stack for this Kata
    tss.set_kernel_stack(target_kata.stack_top);

    // Set current context pointer for interrupt handling
    current_context = &target_kata.context;

    // Perform context switch - pass kernel stack to ensure it's accessible after CR3 switch
    shift_context(&target_kata.context, target_kata.page_table, target_kata.stack_top);
}

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

fn shift_context(ctx: *const Context, page_table: u64, kernel_stack: u64) void {
    const ctx_addr = @intFromPtr(ctx);
    const pt = page_table;
    const kstack = kernel_stack;

    asm volatile (
        \\# Load parameters
        \\mov %[ctx_addr], %%rdi
        \\mov %[pt], %%rsi
        \\
        \\# Switch to kata's higher-half kernel stack
        \\mov %[kstack], %%rsp
        \\
        \\# Read iretq frame values from context struct
        \\mov 152(%%rdi), %%r12    # ctx.ss
        \\mov 56(%%rdi), %%r13     # ctx.rsp
        \\mov 136(%%rdi), %%r14    # ctx.rflags
        \\mov 144(%%rdi), %%r15    # ctx.cs
        \\mov 128(%%rdi), %%rax    # ctx.rip
        \\
        \\# Build iretq frame
        \\pushq %%r12
        \\pushq %%r13
        \\pushq %%r14
        \\pushq %%r15
        \\pushq %%rax
        \\
        \\# Switch to user page table
        \\# Kernel code is at higher-half, so it stays accessible
        \\# mov %%rsi, %%cr3
        \\
        \\# DEBUG: Print 'A' before CR3 switch
        \\mov $0x3F8, %%dx
        \\mov $'A', %%al
        \\out %%al, %%dx
        \\
        \\# Switch to user page table
        \\mov %%rsi, %%cr3
        \\
        \\# DEBUG: Print 'B' after CR3 switch
        \\mov $0x3F8, %%dx
        \\mov $'B', %%al
        \\out %%al, %%dx
        \\
        \\# Zero all registers for clean userspace entry
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
        \\# DEBUG: Print 'C' before iretq
        \\mov $0x3F8, %%dx
        \\mov $'C', %%al
        \\out %%al, %%dx
        \\
        \\# Jump to userspace
        \\iretq
        :
        : [ctx_addr] "r" (ctx_addr),
          [pt] "r" (pt),
          [kstack] "r" (kstack),
        : .{ .memory = true });
    unreachable;
}
