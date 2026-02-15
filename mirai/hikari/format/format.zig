//! Akiba format module

pub const types = @import("types.zig");
pub const parser = @import("parser.zig");

pub const Header = types.Header;
pub const Metadata = types.Metadata;
pub const Executable = types.Executable;

pub const parse = parser.parse;
pub const validate_magic = parser.validate_magic;
