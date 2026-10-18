//! Kagami Ownership State

const common = @import("common");
const cpu = @import("asm").cpu;
const create = @import("mirai").kagami.create;
const types = @import("mirai").kagami.types;

const indices = common.constants.paging.indices;
const Kagami = types.kagami.Kagami;
const Policy = types.policy.Policy;

var kernel_kagami: Kagami = .{};
var current_kagami: *Kagami = &kernel_kagami;
var kernel_policy: Policy = .{};
var initialized: bool = false;

pub fn getKernelKagami() *Kagami {
    return &kernel_kagami;
}

pub fn getCurrentKagami() *Kagami {
    return current_kagami;
}

pub fn getPolicy() *const Policy {
    return &kernel_policy;
}

pub fn setCurrentKagami(kagami: *Kagami) void {
    if (!hasOwnedKernel() or !(kagami.isKernel() or create.owns(kagami)) or
        (cpu.control.readCR3() & indices.ADDRESS_MASK) != kagami.PML4Physical)
    {
        return;
    }
    current_kagami = kagami;
}

pub fn isInitialized() bool {
    return initialized;
}

pub fn hasOwnedKernel() bool {
    return initialized and kernel_kagami.Ownership == .Kernel;
}

pub fn initialize(pml4_physical: u64) void {
    if (initialized) return;
    kernel_kagami.PML4Physical = pml4_physical;
    initialized = true;
}

pub fn publishOwned(kagami: *const Kagami, policy: *const Policy) bool {
    if (hasOwnedKernel() or kagami.Ownership != .Kernel or
        (cpu.control.readCR3() & indices.ADDRESS_MASK) != kagami.PML4Physical)
    {
        return false;
    }
    kernel_kagami = kagami.*;
    kernel_policy = policy.*;
    current_kagami = &kernel_kagami;
    initialized = true;
    return true;
}
