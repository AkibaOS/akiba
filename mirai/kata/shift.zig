//! Context shifting

const context = @import("../asm/context.zig");
const gdt = @import("../boot/gdt/gdt.zig");
const paging = @import("../memory/paging.zig");
const serial = @import("../drivers/serial/serial.zig");
const tss = @import("../boot/tss/tss.zig");
const types = @import("types.zig");

var current_context: ?*types.Context = null;

pub fn to_kata(kata: *types.Kata) void {
    // Validate that the target RIP is mapped in the page table
    if (paging.virt_to_phys(kata.page_table, kata.context.rip) == null) {
        serial.printf("shift: FATAL - kata {d} rip {x} not mapped!\n", .{ kata.id, kata.context.rip });
        paging.dump_pt_structure(kata.page_table, "corrupted");
        while (true) {}
    }

    tss.set_kernel_stack(kata.stack_top);
    current_context = &kata.context;

    context.switch_to_context(
        &kata.context,
        kata.page_table,
        kata.stack_top,
    );
}

pub fn save_current(int_ctx: *const types.InterruptContext) void {
    if (current_context) |ctx| {
        ctx.rax = int_ctx.rax;
        ctx.rbx = int_ctx.rbx;
        ctx.rcx = int_ctx.rcx;
        ctx.rdx = int_ctx.rdx;
        ctx.rsi = int_ctx.rsi;
        ctx.rdi = int_ctx.rdi;
        ctx.rbp = int_ctx.rbp;
        ctx.rsp = int_ctx.rsp;
        ctx.r8 = int_ctx.r8;
        ctx.r9 = int_ctx.r9;
        ctx.r10 = int_ctx.r10;
        ctx.r11 = int_ctx.r11;
        ctx.r12 = int_ctx.r12;
        ctx.r13 = int_ctx.r13;
        ctx.r14 = int_ctx.r14;
        ctx.r15 = int_ctx.r15;
        ctx.rip = int_ctx.rip;
        ctx.rflags = int_ctx.rflags;
        ctx.cs = int_ctx.cs;
        ctx.ss = int_ctx.ss;
    }
}
