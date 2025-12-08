const terminal = @import("../../terminal.zig");
const afs = @import("../../fs/afs.zig");
const ahci = @import("../../drivers/ahci.zig");
const path = @import("../path.zig");

pub fn execute(fs: *afs.AFS(ahci.BlockDevice), current_cluster: u32, args: []const []const u8) void {
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

    var entries: [64]afs.ListEntry = undefined;
    const count = fs.list_directory(target_cluster, &entries) catch {
        terminal.print("ash: failed to list stack\n");
        return;
    };

    for (entries[0..count]) |entry| {
        terminal.print(entry.name[0..entry.name_len]);

        // Add padding for alignment
        var padding: usize = 20;
        if (entry.name_len < 20) {
            padding = 20 - entry.name_len;
        } else {
            padding = 1;
        }

        var i: usize = 0;
        while (i < padding) : (i += 1) {
            terminal.put_char(' ');
        }

        // Print type
        const unit_type = if (entry.is_directory) "<STACK>" else "<UNIT>";
        terminal.print(unit_type);
        terminal.put_char('\n');
    }
}
