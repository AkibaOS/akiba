//! Hikari Paging Subsystem

pub const constants = @import("constants.zig");
pub const types = @import("types.zig");
pub const setup = @import("setup.zig");

pub const PageTableEntry = types.PageTableEntry;
pub const PageTable = types.PageTable;
pub const TableL4 = types.TableL4;
pub const TableL3 = types.TableL3;
pub const TableL2 = types.TableL2;
pub const TableL1 = types.TableL1;

pub const PageTableSetup = setup.PageTableSetup;
pub const SetupError = setup.SetupError;

pub const get_l4_index = types.get_l4_index;
pub const get_l3_index = types.get_l3_index;
pub const get_l2_index = types.get_l2_index;
pub const get_l1_index = types.get_l1_index;
pub const get_page_offset = types.get_page_offset;
