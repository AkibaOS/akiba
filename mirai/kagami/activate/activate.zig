//! Kagami Activation

const common = @import("root").common;
const types = @import("../types/types.zig");
const state = @import("../state.zig");
const asm_cpu = @import("../../asm/cpu/cpu.zig");

const paging_indices = common.constants.paging.indices;

const Kagami = types.Kagami;

pub fn activate(kagami: *Kagami) void {
    asm_cpu.write_cr3(kagami.pml4_physical);
    state.set_current_kagami(kagami);
}

pub fn activate_kernel() void {
    activate(state.get_kernel_kagami());
}

pub fn get_active_pml4() u64 {
    return asm_cpu.read_cr3() & paging_indices.address_mask;
}

pub fn is_active(kagami: *const Kagami) bool {
    return get_active_pml4() == kagami.pml4_physical;
}
