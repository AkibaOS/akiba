//! Memory Region Conversion Module

pub const constants = @import("../constants/regions/regions.zig");
pub const convert_module = @import("convert.zig");
pub const state = @import("state.zig");

pub const convert = convert_module.convert;
