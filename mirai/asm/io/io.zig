//! I/O Operations

pub const port = @import("port.zig");

pub const read_byte = port.read_byte;
pub const write_byte = port.write_byte;
pub const read_word = port.read_word;
pub const write_word = port.write_word;
pub const read_long = port.read_long;
pub const write_long = port.write_long;
pub const io_wait = port.io_wait;
