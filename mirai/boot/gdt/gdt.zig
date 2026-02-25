//! Global Descriptor Table

pub const constants = @import("constants/constants.zig");
pub const types = @import("types/types.zig");
pub const entries = @import("entries/entries.zig");
pub const load = @import("load/load.zig");
pub const state = @import("state.zig");

pub const Entry = types.Entry;
pub const TssDescriptor = types.TssDescriptor;
pub const Gdtr = types.Gdtr;
pub const Table = types.Table;

pub const selectors = constants.selectors;

pub fn initialize(tss_address: u64, tss_size: u20) void {
    state.setup_entries(tss_address, tss_size);

    const gdtr = state.get_gdtr();
    load.lgdt(&gdtr);

    load.reload_segments();

    load.load_tss(selectors.tss_selector);

    state.set_initialized();
}

pub fn is_initialized() bool {
    return state.is_initialized();
}

pub fn get_table() *Table {
    return state.get_table();
}

pub fn update_tss(tss_address: u64, tss_size: u20) void {
    state.update_tss(tss_address, tss_size);
}
