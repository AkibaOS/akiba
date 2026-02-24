//! CPU Control Operations
//! Processor state management and descriptor table operations

/// Halt processor until next interrupt
pub inline fn halt_processor() void {
    asm volatile ("hlt");
}

/// Disable hardware interrupts
pub inline fn disable_interrupts() void {
    asm volatile ("cli");
}

/// Enable hardware interrupts
pub inline fn enable_interrupts() void {
    asm volatile ("sti");
}

/// Load Global Descriptor Table
pub inline fn load_global_descriptor_table(gdtr_address: u64) void {
    asm volatile ("lgdt (%[gdtr])"
        :
        : [gdtr] "r" (gdtr_address),
    );
}

/// Load Interrupt Descriptor Table
pub inline fn load_interrupt_descriptor_table(idtr_address: u64) void {
    asm volatile ("lidt (%[idtr])"
        :
        : [idtr] "r" (idtr_address),
    );
}

/// Load Task Register
pub inline fn load_task_register(selector: u16) void {
    asm volatile ("ltr %[sel]"
        :
        : [sel] "r" (selector),
    );
}

/// Reload all data segment registers with specified selector
pub inline fn reload_segment_registers(selector: u16) void {
    asm volatile (
        \\mov %[sel], %%ds
        \\mov %[sel], %%es
        \\mov %[sel], %%fs
        \\mov %[sel], %%gs
        \\mov %[sel], %%ss
        :
        : [sel] "r" (selector),
    );
}

/// Reload code segment via far return (required after GDT change)
pub inline fn reload_code_segment(selector: u16) void {
    asm volatile (
        \\pushq %[sel]
        \\leaq 1f(%%rip), %%rax
        \\pushq %%rax
        \\lretq
        \\1:
        :
        : [sel] "r" (@as(u64, selector)),
        : .{ .rax = true }
    );
}
