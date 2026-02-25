//! Task State Segment

const gdt = @import("../gdt/gdt.zig");

pub const constants = @import("constants/constants.zig");
pub const types = @import("types/types.zig");
pub const stacks = @import("stacks/stacks.zig");
pub const init = @import("init/init.zig");
pub const state = @import("state.zig");

pub const Tss = types.Tss;
pub const CoreTss = types.CoreTss;

pub fn initialize_boot() void {
    const tss = state.get_boot_tss();
    tss.clear();
    state.set_initialized();
}

pub fn initialize_core(core_id: u16, kernel_stack_top: u64) !*CoreTss {
    const core_tss = state.register_core(core_id) orelse return error.TooManyCores;

    core_tss.tss.clear();
    core_tss.tss.set_rsp0(kernel_stack_top);

    try init.setup_core_tss(core_tss);

    return core_tss;
}

pub fn get_boot_tss() *Tss {
    return state.get_boot_tss();
}

pub fn get_boot_tss_address() u64 {
    return state.get_boot_tss_address();
}

pub fn get_core_tss(core_id: u16) ?*CoreTss {
    return state.get_core_tss(core_id);
}

pub fn get_current_rsp0(core_id: u16) u64 {
    if (state.get_core_tss(core_id)) |core_tss| {
        return core_tss.tss.rsp0;
    }
    return state.get_boot_tss().rsp0;
}

pub fn set_current_rsp0(core_id: u16, stack_top: u64) void {
    if (state.get_core_tss(core_id)) |core_tss| {
        core_tss.tss.set_rsp0(stack_top);
    } else {
        state.get_boot_tss().set_rsp0(stack_top);
    }
}

pub fn is_initialized() bool {
    return state.is_initialized();
}
