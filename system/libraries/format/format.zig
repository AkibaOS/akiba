//! Formatting utilities

pub const int = @import("int.zig");
pub const size = @import("size.zig");
pub const bytes = @import("bytes.zig");
pub const printmod = @import("print.zig");
pub const tablemod = @import("table.zig");

pub const intToStr = int.toStr;
pub const formatSize = size.format;
pub const formatBytes = bytes.format;

pub const print = printmod.print;
pub const println = printmod.println;
pub const printf = printmod.printf;
pub const color = printmod.color;
pub const colorln = printmod.colorln;
pub const colorf = printmod.colorf;

pub const Table = tablemod.Table;
pub const Column = tablemod.Column;
pub const Alignment = tablemod.Alignment;
