const terminal = @import("../../terminal.zig");
const afs = @import("../../fs/afs.zig");
const path = @import("../path.zig");

pub fn execute(fs: *afs.AFS, current_cluster: u32, args: []const []const u8) void {
    var target_cluster = current_cluster;
    var is_directory = true;

    if (args.len > 0) {
        const resolved = path.resolve_path(fs, current_cluster, args[0]) catch |err| {
            terminal.print("ash: location unreachable: ");
            terminal.print(args[0]);

            switch (err) {
                error.NotFound => terminal.print(" (stack not found)"),
                error.ReadFailed => terminal.print(" (read error)"),
                error.InvalidPath => terminal.print(" (invalid path)"),
            }

            terminal.put_char('\n');
            return;
        };

        target_cluster = resolved.cluster;
        is_directory = resolved.is_directory;
    }

    if (!is_directory) {
        terminal.print("ash: not a stack\n");
        return;
    }

    fs.list_directory(target_cluster) catch {
        terminal.print("ash: failed to list stack\n");
        return;
    };
}
