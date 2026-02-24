//! String utilities

pub const cstring = @import("cstring.zig");
pub const location = @import("location.zig");
pub const builder = @import("builder.zig");

pub const len = cstring.len;
pub const toSlice = cstring.toSlice;
pub const findNull = cstring.findNull;

pub const getStackName = location.getStackName;
pub const parent = location.parent;

pub const build = builder.build;
pub const concat = builder.concat;
pub const concat3 = builder.concat3;
