//! Font Preview Executable Entry

const command = @import("fontpreview").command;

pub fn main() !void {
    return command.run();
}
