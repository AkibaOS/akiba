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
        const name = entry.name;

        // Print name (first 8 chars, trim trailing spaces)
        var name_len: usize = 8;
        while (name_len > 0 and name[name_len - 1] == ' ') : (name_len -= 1) {}
        for (name[0..name_len]) |c| {
            terminal.put_char(c);
        }

        // Print extension (last 3 chars, if not all spaces)
        var has_ext = false;
        for (name[8..11]) |c| {
            if (c != ' ') {
                has_ext = true;
                break;
            }
        }

        if (has_ext) {
            terminal.put_char('.');
            var ext_len: usize = 3;
            while (ext_len > 0 and name[8 + ext_len - 1] == ' ') : (ext_len -= 1) {}
            for (name[8 .. 8 + ext_len]) |c| {
                terminal.put_char(c);
            }
        }

        const unit_type = if (entry.is_directory) " <STACK>" else " <UNIT>";
        terminal.print(unit_type);
        terminal.put_char('\n');
    }
}
