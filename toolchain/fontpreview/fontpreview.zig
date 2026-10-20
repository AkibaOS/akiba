//! Font Preview

pub const command = @import("command/command.zig");
pub const constants = @import("constants/constants.zig");
pub const dump = @import("dump/dump.zig");
pub const errors = @import("errors/errors.zig");
pub const render = @import("render/render.zig");
pub const strings = @import("strings/strings.zig");
pub const types = @import("types/types.zig");

pub fn main() !void {
    return command.run();
}
