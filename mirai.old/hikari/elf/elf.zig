//! ELF module

pub const types = @import("types.zig");
pub const parser = @import("parser.zig");

pub const Header = types.Header;
pub const ProgramHeader = types.ProgramHeader;
pub const Info = types.Info;

pub const parse = parser.parse;
