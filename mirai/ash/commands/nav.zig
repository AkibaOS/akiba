const terminal = @import("../../terminal.zig");
const afs = @import("../../fs/afs.zig");
const path = @import("../path.zig");

pub fn execute(
    fs: *afs.AFS,
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

    if (args[0].len == 1 and args[0][0] == '^') {
        const parent = path.get_parent_cluster(fs, current_cluster) catch {
            terminal.print("ash: failed to navigate to parent\n");
            return current_cluster;
        };

        if (current_path_len.* > 1) {
            var i = current_path_len.* - 1;
            while (i > 0) : (i -= 1) {
                if (current_path[i] == '/') {
                    current_path_len.* = if (i == 0) 1 else i;
                    break;
                }
            }
        }

        return parent;
    }

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

    update_path(current_path, current_path_len, args[0], current_cluster, fs.root_cluster);

    return resolved.cluster;
}

fn update_path(
    current_path: []u8,
    current_path_len: *usize,
    new_path: []const u8,
    current_cluster: u32,
    root_cluster: u32,
) void {
    if (new_path.len == 0) return;

    if (new_path[0] == '/') {
        const copy_len = @min(new_path.len, current_path.len - 1);
        for (new_path[0..copy_len], 0..) |c, i| {
            current_path[i] = c;
        }
        current_path_len.* = copy_len;
        return;
    }

    if (current_cluster == root_cluster and current_path_len.* == 1) {
        if (current_path_len.* + 1 + new_path.len < current_path.len) {
            current_path[current_path_len.*] = '/';
            current_path_len.* += 1;

            const copy_len = @min(new_path.len, current_path.len - current_path_len.*);
            for (new_path[0..copy_len], 0..) |c, i| {
                current_path[current_path_len.* + i] = c;
            }
            current_path_len.* += copy_len;
        }
    } else {
        if (current_path_len.* + 1 + new_path.len < current_path.len) {
            if (current_path[current_path_len.* - 1] != '/') {
                current_path[current_path_len.*] = '/';
                current_path_len.* += 1;
            }

            const copy_len = @min(new_path.len, current_path.len - current_path_len.*);
            for (new_path[0..copy_len], 0..) |c, i| {
                current_path[current_path_len.* + i] = c;
            }
            current_path_len.* += copy_len;
        }
    }
}
