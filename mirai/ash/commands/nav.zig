const afs = @import("../../fs/afs.zig");
const ahci = @import("../../drivers/ahci.zig");
const path = @import("../path.zig");
const terminal = @import("../../terminal.zig");

pub fn execute(
    fs: *afs.AFS(ahci.BlockDevice),
    current_cluster: u32,
    current_path: []u8,
    current_path_len: *usize,
    args: []const []const u8,
) u32 {
    if (args.len == 0) {
        terminal.print(current_path[0..current_path_len.*]);
        terminal.put_char('\n');
        return current_cluster;
    }

    // Handle parent directory (^)
    if (args[0].len == 1 and args[0][0] == '^') {
        // Already at root?
        if (current_path_len.* == 1) {
            return current_cluster;
        }

        // Get parent cluster from filesystem
        const parent = fs.get_parent_cluster(current_cluster) orelse {
            terminal.print("ash: failed to navigate to parent\n");
            return current_cluster;
        };

        // Update path - remove last component
        var i = current_path_len.* - 1;
        while (i > 0) {
            i -= 1;
            if (current_path[i] == '/') {
                current_path_len.* = if (i == 0) 1 else i;
                break;
            }
        }

        return parent;
    }

    // Resolve path (case-sensitive)
    const resolved = path.resolve_path(fs, current_cluster, args[0]) catch |err| {
        terminal.print("ash: location unreachable: ");
        terminal.print(args[0]);

        switch (err) {
            error.NotFound => terminal.print(" (stack not found)"),
            error.ReadFailed => terminal.print(" (read error)"),
            error.InvalidPath => terminal.print(" (invalid path)"),
        }

        terminal.put_char('\n');
        return current_cluster;
    };

    if (!resolved.is_directory) {
        terminal.print("ash: not a stack\n");
        return current_cluster;
    }

    // Update path based on input
    if (args[0][0] == '/') {
        // Absolute path - replace current path
        const copy_len = @min(args[0].len, current_path.len - 1);
        for (args[0][0..copy_len], 0..) |c, i| {
            current_path[i] = c;
        }
        current_path_len.* = copy_len;
    } else {
        // Relative path - append to current
        if (current_path_len.* == 1 and current_path[0] == '/') {
            // At root, just add the component
            if (1 + args[0].len < current_path.len) {
                for (args[0], 0..) |c, i| {
                    current_path[1 + i] = c;
                }
                current_path_len.* = 1 + args[0].len;
            }
        } else {
            // Not at root, add slash then component
            if (current_path_len.* + 1 + args[0].len < current_path.len) {
                current_path[current_path_len.*] = '/';
                for (args[0], 0..) |c, i| {
                    current_path[current_path_len.* + 1 + i] = c;
                }
                current_path_len.* += 1 + args[0].len;
            }
        }
    }

    return resolved.cluster;
}
