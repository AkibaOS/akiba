const terminal = @import("../../terminal.zig");
const afs = @import("../../fs/afs.zig");

pub fn execute(fs: *afs.AFS, cluster: u32, args: []const []const u8) void {
    _ = args;

    fs.list_directory(cluster) catch {
        terminal.print("ash: failed to list stack\n");
        return;
    };
}
