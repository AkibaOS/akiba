//! CPU Exception Handlers (0-31)
//! Called when CPU encounters fatal errors

const panic = @import("panic.zig");
const serial = @import("../drivers/serial.zig");
const std = @import("std");

// Exception frame pushed by CPU and our ISR stubs
const InterruptFrame = packed struct {
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

const EXCEPTION_NAMES = [_][]const u8{
    "Division By Zero",
    "Debug",
    "Non-Maskable Interrupt",
    "Breakpoint",
    "Overflow",
    "Bound Range Exceeded",
    "Invalid Opcode",
    "Device Not Available",
    "Double Fault",
    "Coprocessor Segment Overrun",
    "Invalid TSS",
    "Segment Not Present",
    "Stack-Segment Fault",
    "General Protection Fault",
    "Page Fault",
    "Reserved",
    "x87 Floating-Point Exception",
    "Alignment Check",
    "Machine Check",
    "SIMD Floating-Point Exception",
    "Virtualization Exception",
    "Control Protection Exception",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Hypervisor Injection Exception",
    "VMM Communication Exception",
    "Security Exception",
    "Reserved",
};

// Assembly ISR stubs - generate handlers for all 32 exceptions
comptime {
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        if (i == 8 or (i >= 10 and i <= 14) or i == 17 or i == 21) {
            // Exceptions with error code
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

    // Common exception handler - saves all registers
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
}

// Declare ISR symbols for IDT setup
pub extern fn isr0() void;
pub extern fn isr1() void;
pub extern fn isr2() void;
pub extern fn isr3() void;
pub extern fn isr4() void;
pub extern fn isr5() void;
pub extern fn isr6() void;
pub extern fn isr7() void;
pub extern fn isr8() void;
pub extern fn isr9() void;
pub extern fn isr10() void;
pub extern fn isr11() void;
pub extern fn isr12() void;
pub extern fn isr13() void;
pub extern fn isr14() void;
pub extern fn isr15() void;
pub extern fn isr16() void;
pub extern fn isr17() void;
pub extern fn isr18() void;
pub extern fn isr19() void;
pub extern fn isr20() void;
pub extern fn isr21() void;
pub extern fn isr22() void;
pub extern fn isr23() void;
pub extern fn isr24() void;
pub extern fn isr25() void;
pub extern fn isr26() void;
pub extern fn isr27() void;
pub extern fn isr28() void;
pub extern fn isr29() void;
pub extern fn isr30() void;
pub extern fn isr31() void;

// Get all ISR addresses as array (for IDT setup)
pub fn get_isr_handlers() [32]u64 {
    return [_]u64{
        @intFromPtr(&isr0),  @intFromPtr(&isr1),  @intFromPtr(&isr2),  @intFromPtr(&isr3),
        @intFromPtr(&isr4),  @intFromPtr(&isr5),  @intFromPtr(&isr6),  @intFromPtr(&isr7),
        @intFromPtr(&isr8),  @intFromPtr(&isr9),  @intFromPtr(&isr10), @intFromPtr(&isr11),
        @intFromPtr(&isr12), @intFromPtr(&isr13), @intFromPtr(&isr14), @intFromPtr(&isr15),
        @intFromPtr(&isr16), @intFromPtr(&isr17), @intFromPtr(&isr18), @intFromPtr(&isr19),
        @intFromPtr(&isr20), @intFromPtr(&isr21), @intFromPtr(&isr22), @intFromPtr(&isr23),
        @intFromPtr(&isr24), @intFromPtr(&isr25), @intFromPtr(&isr26), @intFromPtr(&isr27),
        @intFromPtr(&isr28), @intFromPtr(&isr29), @intFromPtr(&isr30), @intFromPtr(&isr31),
    };
}

// Main exception handler - called from assembly stub
export fn exception_handler(frame: *InterruptFrame) void {
    // Read control registers
    const cr2 = asm volatile ("mov %%cr2, %[result]"
        : [result] "=r" (-> u64),
    );
    const cr3 = asm volatile ("mov %%cr3, %[result]"
        : [result] "=r" (-> u64),
    );

    const int_num = frame.int_num;

    // Build context for Crimson
    var context = panic.Context{
        .rax = frame.rax,
        .rbx = frame.rbx,
        .rcx = frame.rcx,
        .rdx = frame.rdx,
        .rsi = frame.rsi,
        .rdi = frame.rdi,
        .rbp = frame.rbp,
        .rsp = frame.rsp,
        .r8 = frame.r8,
        .r9 = frame.r9,
        .r10 = frame.r10,
        .r11 = frame.r11,
        .r12 = frame.r12,
        .r13 = frame.r13,
        .r14 = frame.r14,
        .r15 = frame.r15,
        .rip = frame.rip,
        .rflags = frame.rflags,
        .error_code = frame.error_code,
        .cr2 = cr2,
        .cr3 = cr3,
    };

    // Format error message
    var message_buffer: [256]u8 = undefined;
    const message = format_exception_message(int_num, &context, &message_buffer);

    // Trigger Crimson
    panic.collapse(message, &context);
}

fn format_exception_message(int_num: u64, context: *const panic.Context, buffer: []u8) []const u8 {
    var pos: usize = 0;

    // Exception name
    if (int_num < 32) {
        const name = EXCEPTION_NAMES[int_num];
        for (name) |c| {
            if (pos < buffer.len) {
                buffer[pos] = c;
                pos += 1;
            }
        }
    } else {
        const unknown = "Unknown Exception";
        for (unknown) |c| {
            if (pos < buffer.len) {
                buffer[pos] = c;
                pos += 1;
            }
        }
    }

    // Add special info for page faults
    if (int_num == 14) {
        const pf_info = format_page_fault_info(context.error_code, buffer[pos..]);
        pos += pf_info.len;
    }

    return buffer[0..pos];
}

fn format_page_fault_info(error_code: u64, buffer: []u8) []const u8 {
    var pos: usize = 0;

    const info = " (";
    for (info) |c| {
        if (pos < buffer.len) {
            buffer[pos] = c;
            pos += 1;
        }
    }

    // Present or not present
    if ((error_code & 1) != 0) {
        const present = "protection";
        for (present) |c| {
            if (pos < buffer.len) {
                buffer[pos] = c;
                pos += 1;
            }
        }
    } else {
        const not_present = "not present";
        for (not_present) |c| {
            if (pos < buffer.len) {
                buffer[pos] = c;
                pos += 1;
            }
        }
    }

    // Read or write
    if ((error_code & 2) != 0) {
        const write_str = ", write";
        for (write_str) |c| {
            if (pos < buffer.len) {
                buffer[pos] = c;
                pos += 1;
            }
        }
    } else {
        const read_str = ", read";
        for (read_str) |c| {
            if (pos < buffer.len) {
                buffer[pos] = c;
                pos += 1;
            }
        }
    }

    // User or kernel
    if ((error_code & 4) != 0) {
        const user_str = ", user";
        for (user_str) |c| {
            if (pos < buffer.len) {
                buffer[pos] = c;
                pos += 1;
            }
        }
    } else {
        const kernel_str = ", kernel";
        for (kernel_str) |c| {
            if (pos < buffer.len) {
                buffer[pos] = c;
                pos += 1;
            }
        }
    }

    if (pos < buffer.len) {
        buffer[pos] = ')';
        pos += 1;
    }

    return buffer[0..pos];
}
