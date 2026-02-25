//! Kagami - Page Table Abstraction

pub const constants = @import("constants/constants.zig");
pub const types = @import("types/types.zig");
pub const tables = @import("tables/tables.zig");
pub const state = @import("state.zig");

pub const create_module = @import("create/create.zig");
pub const destroy_module = @import("destroy/destroy.zig");
pub const enter_module = @import("enter/enter.zig");
pub const remove_module = @import("remove/remove.zig");
pub const protect_module = @import("protect/protect.zig");
pub const extract_module = @import("extract/extract.zig");
pub const activate_module = @import("activate/activate.zig");

pub const Kagami = types.Kagami;
pub const Entry = types.Entry;
pub const Table = types.Table;

pub const create = create_module.create;
pub const destroy = destroy_module.destroy;
pub const reference = destroy_module.reference;
pub const release = destroy_module.release;

pub const enter = enter_module.enter;
pub const enter_replace = enter_module.enter_replace;

pub const remove = remove_module.remove;
pub const remove_range = remove_module.remove_range;

pub const protect = protect_module.protect;
pub const protect_range = protect_module.protect_range;

pub const extract = extract_module.extract;
pub const is_mapped = extract_module.is_mapped;
pub const is_writable = extract_module.is_writable;
pub const is_user_accessible = extract_module.is_user_accessible;

pub const activate = activate_module.activate;
pub const activate_kernel = activate_module.activate_kernel;
pub const get_active_pml4 = activate_module.get_active_pml4;
pub const is_active = activate_module.is_active;

pub const kernel = state.get_kernel_kagami;
pub const current = state.get_current_kagami;
pub const is_initialized = state.is_initialized;

pub fn initialize(pml4_physical: u64) void {
    state.set_kernel_pml4(pml4_physical);
    state.set_initialized();
}
