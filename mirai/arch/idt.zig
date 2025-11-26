//! Interrupt Descriptor Table

const serial = @import("../drivers/serial.zig");

const IDTEntry = packed struct {
    offset_low: u16,
    selector: u16,
    ist: u8,
    type_attr: u8,
    offset_mid: u16,
    offset_high: u32,
    reserved: u32,
};

const IDTPointer = packed struct {
    limit: u16,
    base: u64,
};

var idt: [256]IDTEntry = [_]IDTEntry{.{
    .offset_low = 0,
    .selector = 0,
    .ist = 0,
    .type_attr = 0,
    .offset_mid = 0,
    .offset_high = 0,
    .reserved = 0,
}} ** 256;

comptime {
    asm (
        \\.global exception_handler_asm
        \\exception_handler_asm:
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
        \\  call exception_handler_inner
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

extern fn exception_handler_asm() void;

export fn exception_handler_inner() void {
    serial.print("\r\n!!! CPU EXCEPTION !!!\r\n");
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn init() void {
    serial.print("Setting up IDT...\r\n");

    var i: u16 = 0;
    while (i < 32) : (i += 1) {
        set_handler(i);
    }

    const idtr = IDTPointer{
        .limit = @sizeOf(@TypeOf(idt)) - 1,
        .base = @intFromPtr(&idt),
    };

    asm volatile ("lidt (%[idtr])"
        :
        : [idtr] "r" (&idtr),
    );

    serial.print("IDT loaded\r\n");
}

fn set_handler(vector: u16) void {
    const addr = @intFromPtr(&exception_handler_asm);

    idt[vector] = .{
        .offset_low = @truncate(addr),
        .selector = 0x08,
        .ist = 0,
        .type_attr = 0x8E,
        .offset_mid = @truncate(addr >> 16),
        .offset_high = @truncate(addr >> 32),
        .reserved = 0,
    };
}
