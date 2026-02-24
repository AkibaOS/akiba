//! Hikari Paging Subsystem

pub const constants = @import("constants.zig");
pub const types = @import("types.zig");
pub const setup = @import("setup.zig");

pub const PageTableEntry = types.PageTableEntry;
pub const PageTable = types.PageTable;
pub const PageMapLevel4 = types.PageMapLevel4;
pub const PageDirectoryPointerTable = types.PageDirectoryPointerTable;
pub const PageDirectory = types.PageDirectory;
pub const PageTableLevel1 = types.PageTableLevel1;

pub const PageTableSetup = setup.PageTableSetup;
pub const SetupError = setup.SetupError;

pub const get_pml4_index = types.get_pml4_index;
pub const get_pdpt_index = types.get_pdpt_index;
pub const get_pd_index = types.get_pd_index;
pub const get_pt_index = types.get_pt_index;
pub const get_page_offset = types.get_page_offset;
