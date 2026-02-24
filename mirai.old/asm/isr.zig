//! Interrupt Service Routine Stubs
//! Assembly entry points for exceptions and hardware interrupts

const std = @import("std");

// External handlers (implemented in Zig)
extern fn exception_handler(ctx: u64) void;
extern fn timer_handler() void;
extern fn keyboard_handler() void;

// ISR function type for IDT registration
pub const ISRHandler = *const fn () callconv(.c) void;

/// Get ISR handler address for exception vector
pub fn get_exception_handler(vector: u8) ISRHandler {
    return switch (vector) {
        0 => &isr0,
        1 => &isr1,
        2 => &isr2,
        3 => &isr3,
        4 => &isr4,
        5 => &isr5,
        6 => &isr6,
        7 => &isr7,
        8 => &isr8,
        9 => &isr9,
        10 => &isr10,
        11 => &isr11,
        12 => &isr12,
        13 => &isr13,
        14 => &isr14,
        15 => &isr15,
        16 => &isr16,
        17 => &isr17,
        18 => &isr18,
        19 => &isr19,
        20 => &isr20,
        21 => &isr21,
        22 => &isr22,
        23 => &isr23,
        24 => &isr24,
        25 => &isr25,
        26 => &isr26,
        27 => &isr27,
        28 => &isr28,
        29 => &isr29,
        30 => &isr30,
        31 => &isr31,
        else => &isr0,
    };
}

/// Get IRQ handler address
pub fn get_irq_handler(irq: u8) ISRHandler {
    return switch (irq) {
        0 => &irq0_handler,
        1 => &irq1_handler,
        else => &irq0_handler,
    };
}

// Exception ISR stubs (0-31)
comptime {
    // Generate ISR stubs for all 32 exceptions
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        if (i == 8 or (i >= 10 and i <= 14) or i == 17 or i == 21) {
            // Exceptions with error code pushed by CPU
            asm (std.fmt.comptimePrint(
                    \\.global isr{d}
                    \\isr{d}:
                    \\  push ${d}
                    \\  jmp common_exception_handler
                , .{ i, i, i }));
        } else {
            // Exceptions without error code - push dummy 0
            asm (std.fmt.comptimePrint(
                    \\.global isr{d}
                    \\isr{d}:
                    \\  push $0
                    \\  push ${d}
                    \\  jmp common_exception_handler
                , .{ i, i, i }));
        }
    }

    // Common exception handler - saves all registers and calls Zig handler
    asm (
        \\common_exception_handler:
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
        \\  mov %rsp, %rdi
        \\  call exception_handler
        \\  pop %r15
        \\  pop %r14
        \\  pop %r13
        \\  pop %r12
        \\  pop %r11
        \\  pop %r10
        \\  pop %r9
        \\  pop %r8
        \\  pop %rbp
        \\  pop %rdi
        \\  pop %rsi
        \\  pop %rdx
        \\  pop %rcx
        \\  pop %rbx
        \\  pop %rax
        \\  add $16, %rsp
        \\  iretq
    );

    // IRQ handlers
    asm (
        \\.global irq0_handler
        \\irq0_handler:
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
        \\  call timer_handler
        \\  pop %r15
        \\  pop %r14
        \\  pop %r13
        \\  pop %r12
        \\  pop %r11
        \\  pop %r10
        \\  pop %r9
        \\  pop %r8
        \\  pop %rbp
        \\  pop %rdi
        \\  pop %rsi
        \\  pop %rdx
        \\  pop %rcx
        \\  pop %rbx
        \\  pop %rax
        \\  iretq
        \\
        \\.global irq1_handler
        \\irq1_handler:
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
        \\  call keyboard_handler
        \\  pop %r15
        \\  pop %r14
        \\  pop %r13
        \\  pop %r12
        \\  pop %r11
        \\  pop %r10
        \\  pop %r9
        \\  pop %r8
        \\  pop %rbp
        \\  pop %rdi
        \\  pop %rsi
        \\  pop %rdx
        \\  pop %rcx
        \\  pop %rbx
        \\  pop %rax
        \\  iretq
    );
}

// Extern declarations for ISR addresses
extern fn isr0() callconv(.c) void;
extern fn isr1() callconv(.c) void;
extern fn isr2() callconv(.c) void;
extern fn isr3() callconv(.c) void;
extern fn isr4() callconv(.c) void;
extern fn isr5() callconv(.c) void;
extern fn isr6() callconv(.c) void;
extern fn isr7() callconv(.c) void;
extern fn isr8() callconv(.c) void;
extern fn isr9() callconv(.c) void;
extern fn isr10() callconv(.c) void;
extern fn isr11() callconv(.c) void;
extern fn isr12() callconv(.c) void;
extern fn isr13() callconv(.c) void;
extern fn isr14() callconv(.c) void;
extern fn isr15() callconv(.c) void;
extern fn isr16() callconv(.c) void;
extern fn isr17() callconv(.c) void;
extern fn isr18() callconv(.c) void;
extern fn isr19() callconv(.c) void;
extern fn isr20() callconv(.c) void;
extern fn isr21() callconv(.c) void;
extern fn isr22() callconv(.c) void;
extern fn isr23() callconv(.c) void;
extern fn isr24() callconv(.c) void;
extern fn isr25() callconv(.c) void;
extern fn isr26() callconv(.c) void;
extern fn isr27() callconv(.c) void;
extern fn isr28() callconv(.c) void;
extern fn isr29() callconv(.c) void;
extern fn isr30() callconv(.c) void;
extern fn isr31() callconv(.c) void;
extern fn irq0_handler() callconv(.c) void;
extern fn irq1_handler() callconv(.c) void;
