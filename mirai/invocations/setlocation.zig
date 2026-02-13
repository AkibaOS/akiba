//! Setlocation invocation - Change current stack location

const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const handler = @import("handler.zig");
const kata_mod = @import("../kata/kata.zig");
const sensei = @import("../kata/sensei.zig");
const string = @import("../utils/string.zig");
const system = @import("../system/system.zig");

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const fs = afs_instance orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const path_ptr = ctx.rdi;
    const path_len = ctx.rsi;

    if (!system.is_valid_user_pointer(path_ptr)) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    if (path_len > system.limits.MAX_PATH_LENGTH) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    const kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    var path_buf: [system.limits.MAX_PATH_LENGTH]u8 = undefined;
    const path_src = @as([*]const u8, @ptrFromInt(path_ptr));
    for (0..path_len) |i| {
        path_buf[i] = path_src[i];
    }
    const path = path_buf[0..path_len];

    const target_cluster = resolve_path(fs, kata, path) orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const canonical = canonicalize_path(kata, path);

    for (0..canonical.len) |i| {
        kata.current_location[i] = canonical.path[i];
    }
    kata.current_location_len = canonical.len;
    kata.current_cluster = target_cluster;

    // Auto-send NAVIGATE letter to parent
    if (kata.parent_id != 0) {
        if (kata_mod.get_kata(kata.parent_id)) |parent| {
            parent.letter_type = 1; // NAVIGATE
            parent.letter_len = @intCast(canonical.len);
            for (0..canonical.len) |i| {
                parent.letter_data[i] = canonical.path[i];
            }
        }
    }

    ctx.rax = 0;
}

const CanonicalPath = struct {
    path: [system.limits.MAX_PATH_LENGTH]u8,
    len: usize,
};

fn canonicalize_path(kata: *const kata_mod.Kata, path: []const u8) CanonicalPath {
    var result: CanonicalPath = .{
        .path = undefined,
        .len = 0,
    };

    if (path.len == 1 and path[0] == '^') {
        for (0..kata.current_location_len) |i| {
            result.path[i] = kata.current_location[i];
        }
        result.len = kata.current_location_len;

        if (result.len > 1) {
            result.len -= 1;
            while (result.len > 1 and result.path[result.len - 1] != '/') {
                result.len -= 1;
            }
            if (result.len > 1) result.len -= 1;
        }
        if (result.len == 0) {
            result.path[0] = '/';
            result.len = 1;
        }
        return result;
    }

    if (path.len > 0 and path[0] == '/') {
        result.path[0] = '/';
        result.len = 1;

        var i: usize = 1;
        while (i < path.len) {
            while (i < path.len and path[i] == '/') : (i += 1) {}
            if (i >= path.len) break;

            const start = i;
            while (i < path.len and path[i] != '/') : (i += 1) {}
            const component = path[start..i];

            if (string.strings_equal(component, "^")) {
                if (result.len > 1) {
                    result.len -= 1;
                    while (result.len > 1 and result.path[result.len - 1] != '/') {
                        result.len -= 1;
                    }
                    if (result.len > 1) result.len -= 1;
                }
            } else {
                if (result.len > 1) {
                    result.path[result.len] = '/';
                    result.len += 1;
                }
                for (component) |c| {
                    if (result.len < system.limits.MAX_PATH_LENGTH) {
                        result.path[result.len] = c;
                        result.len += 1;
                    }
                }
            }
        }

        return result;
    }

    for (0..kata.current_location_len) |i| {
        result.path[i] = kata.current_location[i];
    }
    result.len = kata.current_location_len;

    var i: usize = 0;
    while (i < path.len) {
        while (i < path.len and path[i] == '/') : (i += 1) {}
        if (i >= path.len) break;

        const start = i;
        while (i < path.len and path[i] != '/') : (i += 1) {}
        const component = path[start..i];

        if (string.strings_equal(component, "^")) {
            if (result.len > 1) {
                result.len -= 1;
                while (result.len > 1 and result.path[result.len - 1] != '/') {
                    result.len -= 1;
                }
                if (result.len > 1) result.len -= 1;
            }
        } else {
            if (result.len > 1) {
                result.path[result.len] = '/';
                result.len += 1;
            }
            for (component) |c| {
                if (result.len < system.limits.MAX_PATH_LENGTH) {
                    result.path[result.len] = c;
                    result.len += 1;
                }
            }
        }
    }

    return result;
}

fn resolve_path(fs: *afs.AFS(ahci.BlockDevice), kata: *const kata_mod.Kata, path: []const u8) ?u32 {
    var cluster: u32 = undefined;
    var start: usize = 0;

    const current: u32 = if (kata.current_cluster == 0) fs.root_cluster else @as(u32, @intCast(kata.current_cluster));

    if (path.len == 1 and path[0] == '^') {
        return fs.get_parent_cluster(current) orelse fs.root_cluster;
    }

    if (path.len > 0 and path[0] == '/') {
        cluster = fs.root_cluster;
        start = 1;
    } else {
        cluster = current;
    }

    if (start >= path.len) {
        return cluster;
    }

    var i: usize = start;
    while (i <= path.len) : (i += 1) {
        const is_end = (i == path.len);
        const is_slash = !is_end and path[i] == '/';

        if (is_slash or is_end) {
            if (i > start) {
                const component = path[start..i];

                if (string.strings_equal(component, "^")) {
                    cluster = fs.get_parent_cluster(cluster) orelse fs.root_cluster;
                } else {
                    const entry = fs.find_file(cluster, component) orelse return null;
                    if (entry.entry_type != afs.ENTRY_TYPE_DIR) return null;
                    cluster = entry.first_cluster;
                }
            }
            start = i + 1;
        }
    }

    return cluster;
}
