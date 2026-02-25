//! Page Table Operations

pub const walk = @import("walk.zig");
pub const allocate = @import("allocate.zig");

pub const get_table_from_physical = walk.get_table_from_physical;
pub const get_pml4 = walk.get_pml4;
pub const get_pdpt = walk.get_pdpt;
pub const get_pd = walk.get_pd;
pub const get_pt = walk.get_pt;
pub const walk_to_entry = walk.walk_to_entry;

pub const allocate_table = allocate.allocate_table;
pub const free_table = allocate.free_table;
pub const ensure_pdpt = allocate.ensure_pdpt;
pub const ensure_pd = allocate.ensure_pd;
pub const ensure_pt = allocate.ensure_pt;
pub const ensure_tables = allocate.ensure_tables;
