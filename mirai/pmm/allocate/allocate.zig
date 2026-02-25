//! Physical Page Allocation

pub const single = @import("single.zig");
pub const contiguous = @import("contiguous.zig");

pub const allocate_page = single.allocate_page;
pub const allocate_page_zeroed = single.allocate_page_zeroed;
pub const allocate_contiguous = contiguous.allocate_contiguous;
pub const allocate_contiguous_zeroed = contiguous.allocate_contiguous_zeroed;
pub const allocate_aligned = contiguous.allocate_aligned;
