//! Disk Image Tool

pub const command = @import("command/command.zig");
pub const constants = @import("constants/constants.zig");
pub const errors = @import("errors/errors.zig");
pub const image = @import("image/image.zig");
pub const strings = @import("strings/strings.zig");
pub const types = @import("types/types.zig");

pub fn main() !void {
    return command.run();
}
