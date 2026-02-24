//! mi - Stack viewer for Akiba OS

const colors = @import("colors");
const datetime = @import("datetime");
const format = @import("format");
const io = @import("io");
const params = @import("params");
const sys = @import("sys");

const PERM_OWNER: u8 = 1;
const PERM_WORLD: u8 = 2;
const PERM_READ_ONLY: u8 = 3;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    const p = params.parse(pc, pv) catch |err| {
        format.color("mi: ", colors.red);
        format.println(@errorName(err));
        return 1;
    };

    var target_path: []const u8 = "";

    if (p.positionals.len > 1) {
        format.colorln("mi: invalid number of positional parameters.", colors.red);
        return 1;
    }

    if (p.named.len > 0) {
        format.colorln("mi: named parameters are not supported.", colors.red);
        return 1;
    }

    if (p.positional(0)) |val| {
        switch (val) {
            .scalar => |s| target_path = s,
            .list => {
                format.colorln("mi: only one location allowed", colors.red);
                return 1;
            },
        }
    }

    display_stack(target_path) catch {
        return 1;
    };

    return 0;
}

fn display_stack(path: []const u8) !void {
    var entries: [128]io.StackEntry = undefined;
    const count = io.viewstack(path, &entries) catch {
        format.color("mi: cannot access '", colors.red);
        format.print(path);
        format.colorln("': No such stack.", colors.red);
        return error.Failed;
    };

    if (count == 0) {
        format.color(path, colors.cyan);
        format.colorln(" is empty.", colors.gray);
        return;
    }

    var table = format.Table.init(&[_]format.Column{
        .{ .name = "Access", .color = colors.cyan },
        .{ .name = "Size", .color = colors.green },
        .{ .name = "Persona", .color = colors.yellow },
        .{ .name = "Modified", .color = colors.blue },
        .{ .name = "Name", .color = colors.white },
    });

    var stack_count: usize = 0;
    var unit_count: usize = 0;
    var total_size: u64 = 0;

    var size_bufs: [128][32]u8 = undefined;
    var date_bufs: [128][32]u8 = undefined;
    var name_bufs: [128][65]u8 = undefined;

    for (0..count) |i| {
        const entry = &entries[i];

        const perms = get_permissions(entry.permission_type);
        const size_str = format.formatSize(entry.size, &size_bufs[i]);
        const date_str = datetime.formatDate(entry.modified_time, &date_bufs[i]);
        const owner = entry.owner_name[0..entry.owner_name_len];
        const identity = entry.identity[0..entry.identity_len];

        // Build name with optional /
        var name_len: usize = identity.len;
        @memcpy(name_bufs[i][0..identity.len], identity);
        if (entry.is_stack) {
            name_bufs[i][name_len] = '/';
            name_len += 1;
            stack_count += 1;
        } else {
            unit_count += 1;
        }
        total_size += entry.size;

        const name_color: u32 = if (entry.is_stack) colors.cyan else colors.white;

        table.rowColored(
            &[_][]const u8{ perms, size_str, owner, date_str, name_bufs[i][0..name_len] },
            &[_]u32{ colors.cyan, colors.green, colors.yellow, colors.blue, name_color },
        );
    }

    table.print();

    format.print("\n");

    var buf: [16]u8 = undefined;
    format.color(format.intToStr(stack_count, &buf), colors.gray);
    format.color(" stacks  ", colors.gray);
    format.color(format.intToStr(unit_count, &buf), colors.gray);
    format.color(" units  ", colors.gray);
    var size_buf: [32]u8 = undefined;
    format.colorln(format.formatSize(total_size, &size_buf), colors.gray);
}

fn get_permissions(perm_type: u8) []const u8 {
    return switch (perm_type) {
        PERM_OWNER => "Owner",
        PERM_WORLD => "World",
        PERM_READ_ONLY => "Read Only",
        else => "Owner",
    };
}
