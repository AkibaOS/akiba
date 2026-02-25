//! GDT Entries

pub const kernel = @import("kernel.zig");
pub const user = @import("user.zig");
pub const tss = @import("tss.zig");

pub const create_kernel_code = kernel.create_kernel_code;
pub const create_kernel_data = kernel.create_kernel_data;
pub const create_user_code = user.create_user_code;
pub const create_user_data = user.create_user_data;
pub const create_tss_descriptor = tss.create_tss_descriptor;
pub const mark_tss_busy = tss.mark_tss_busy;
pub const mark_tss_available = tss.mark_tss_available;
