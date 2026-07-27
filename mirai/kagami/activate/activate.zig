//! Kagami Activation

const common = @import("common");

const cpu = @import("asm").cpu;

const state = @import("../state/state.zig");
const types = @import("../types/types.zig");

const indices = common.constants.paging.indices;

const Kagami = types.kagami.Kagami;

pub fn activate(kagami: *Kagami) void {
    cpu.control.writeCR3(kagami.PML4Physical);
    state.setCurrentKagami(kagami);
}

pub fn activateKernel() void {
    activate(state.getKernelKagami());
}

pub fn getActivePML4() u64 {
    return cpu.control.readCR3() & indices.ADDRESS_MASK;
}

pub fn isActive(kagami: *const Kagami) bool {
    return getActivePML4() == kagami.PML4Physical;
}
