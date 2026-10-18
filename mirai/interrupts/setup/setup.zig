//! Exception and Hardware Interrupt Setup

const common = @import("common");

const boot = @import("mirai").boot;
const handlers = @import("mirai").interrupts.handlers;
const interrupt = @import("asm").interrupts;
const load = @import("mirai").interrupts.load;
const pic = @import("mirai").interrupts.pic;
const table = @import("mirai").interrupts.table;
const types = @import("mirai").interrupts.types;

const vectors = common.constants.interrupts.vectors;

var exceptions_initialized: bool = false;
var hardware_initialized: bool = false;

pub fn initializeExceptions() void {
    if (exceptions_initialized) return;

    interrupt.flags.disableInterrupts();
    const selector = boot.constants.gdt.selectors.KERNEL_CODE_SELECTOR;

    for (0..vectors.EXCEPTION_COUNT) |index| {
        const vector: u8 = @intCast(index);
        const handler_address = @intFromPtr(handlers.exceptions.stubs[index]);
        table.install.setInterruptIST(vector, handler_address, selector, getExceptionIST(vector));
    }

    load.lidt.load();
    exceptions_initialized = true;
}

fn getExceptionIST(vector: u8) u3 {
    return switch (vector) {
        vectors.DEBUG_VECTOR => @intCast(boot.constants.tss.limits.IST_DEBUG),
        vectors.NMI_VECTOR => @intCast(boot.constants.tss.limits.IST_NMI),
        vectors.DOUBLE_FAULT_VECTOR => @intCast(boot.constants.tss.limits.IST_DOUBLE_FAULT),
        vectors.MACHINE_CHECK_VECTOR => @intCast(boot.constants.tss.limits.IST_MACHINE_CHECK),
        else => 0,
    };
}

pub fn isExceptionsInitialized() bool {
    if (!exceptions_initialized) return false;

    const descriptor = load.lidt.store();
    const expected = types.descriptor.Descriptor.fromTable(&table.entries.entries);
    if (descriptor.Base != expected.Base or descriptor.Limit != expected.Limit) return false;

    for (0..vectors.EXCEPTION_COUNT) |index| {
        const vector: u8 = @intCast(index);
        const gate = table.entries.entries[index];
        if (!gate.Present or gate.GateType != .Interrupt or gate.DPL != .Ring0 or
            gate.Selector != boot.constants.gdt.selectors.KERNEL_CODE_SELECTOR or
            gate.IST != getExceptionIST(vector) or
            gate.getOffset() != @intFromPtr(handlers.exceptions.stubs[index])) return false;
    }
    return true;
}

pub fn initializeHardware() bool {
    if (!isExceptionsInitialized()) return false;
    if (hardware_initialized) return true;

    interrupt.flags.disableInterrupts();
    pic.init.remap();
    pic.mask.maskAll();

    const selector = boot.constants.gdt.selectors.KERNEL_CODE_SELECTOR;
    for (0..vectors.IRQ_COUNT) |index| {
        const vector: u8 = @as(u8, @intCast(index)) + vectors.VECTOR_OFFSET;
        const handler_address = @intFromPtr(handlers.hardware.stubs[index]);
        table.install.setInterrupt(vector, handler_address, selector);
    }

    hardware_initialized = true;
    return true;
}

pub fn enable() void {
    if (hardware_initialized and isExceptionsInitialized()) interrupt.flags.enableInterrupts();
}

pub fn disable() void {
    interrupt.flags.disableInterrupts();
}
