//! User Callable Invocation Gate

const common = @import("common");
const entries = @import("mirai").interrupts.table.entries;
const guard = @import("asm").interrupts.guard;
const install = @import("mirai").interrupts.table.install;
const selectors = @import("mirai").boot.constants.gdt.selectors;
const stubs = @import("asm").interrupts.stubs;

var initialized: bool = false;

pub fn initialize() bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (initialized) return false;
    const vector = common.constants.interrupts.vectors.INVOCATION_VECTOR;
    if (entries.entries[vector].Present) return false;
    const handler = stubs.makeInvocationHandler();
    const address = @intFromPtr(&handler);
    install.setGate(vector, address, selectors.KERNEL_CODE_SELECTOR, 0, .Ring3, .Interrupt);
    const gate = entries.entries[vector];
    if (!gate.Present or gate.DPL != .Ring3 or gate.GateType != .Interrupt or gate.IST != 0 or
        gate.Selector != selectors.KERNEL_CODE_SELECTOR or gate.getOffset() != address) return false;
    initialized = true;
    return true;
}

pub fn isInitialized() bool {
    return initialized;
}
