//! Disk Image Tool Executable Entry

const command = @import("mkafsdisk").command;

pub fn main() !void {
    return command.run();
}
