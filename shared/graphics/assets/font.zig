//! Embedded Console Font

const graphics = @import("shared").graphics;

const Header = graphics.types.font.Header;

const RAW = @embedFile("font");

pub const DEFAULT: [RAW.len]u8 align(@alignOf(Header)) = RAW.*;
