//! Viewstack syscall - List contents of a stack (directory)

const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const handler = @import("handler.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial.zig");
const system = @import("../system/system.zig");

const UserStackEntry = extern struct {
    identity: [64]u8,
    identity_len: u8,
    is_stack: bool,
    owner_name_len: u8,
    permission_type: u8,
    size: u32,
    modified_time: u64,
    owner_name: [64]u8,
};

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const fs = afs_instance orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const location_ptr = ctx.rdi;
    const location_len = ctx.rsi;
    const entries_ptr = ctx.rdx;
    const max_entries = ctx.r10;

    if (!system.is_valid_user_pointer(location_ptr) or !system.is_valid_user_pointer(entries_ptr)) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    if (location_len > system.limits.MAX_PATH_LENGTH) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    // Copy path from userspace
    var location_buf: [system.limits.MAX_PATH_LENGTH]u8 = undefined;
    const location_src = @as([*]const u8, @ptrFromInt(location_ptr));
    for (0..location_len) |i| {
        location_buf[i] = location_src[i];
    }
    const path = location_buf[0..location_len];

    // Resolve path to cluster
    const target_cluster = resolve_path_to_cluster(fs, path) orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    var kernel_entries: [32]afs.ListEntry = undefined;
    const entry_count = fs.list_directory(target_cluster, &kernel_entries) catch {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const user_entries = @as([*]UserStackEntry, @ptrFromInt(entries_ptr));
    const copy_count = @min(entry_count, max_entries);

    for (0..copy_count) |i| {
        const entry = &kernel_entries[i];
        var user_entry = &user_entries[i];

        const name_len = @min(entry.name_len, 63);
        for (0..name_len) |j| {
            user_entry.identity[j] = entry.name[j];
        }
        user_entry.identity_len = @as(u8, @intCast(name_len));
        user_entry.size = entry.file_size;
        user_entry.is_stack = entry.is_directory;
        user_entry.modified_time = entry.modified_time;

        // Copy owner name
        const owner_len = @min(entry.owner_name_len, 63);
        for (0..owner_len) |j| {
            user_entry.owner_name[j] = entry.owner_name[j];
        }
        user_entry.owner_name_len = @as(u8, @intCast(owner_len));
        user_entry.permission_type = entry.permission_type;
    }

    ctx.rax = copy_count;
}

/// Resolve a path to its directory cluster
fn resolve_path_to_cluster(fs: *afs.AFS(ahci.BlockDevice), path: []const u8) ?u32 {
    // Empty path or "/" means root
    if (path.len == 0) {
        return fs.root_cluster;
    }

    var cluster = fs.root_cluster;
    var start: usize = 0;

    // Skip leading slash
    if (path[0] == '/') {
        start = 1;
    }

    // If path is just "/", return root
    if (start >= path.len) {
        return fs.root_cluster;
    }

    var i: usize = start;
    while (i <= path.len) : (i += 1) {
        const is_end = (i == path.len);
        const is_slash = !is_end and path[i] == '/';

        if (is_slash or is_end) {
            if (i > start) {
                const component = path[start..i];

                // Find this component in current directory
                const entry = fs.find_file(cluster, component) orelse {
                    return null;
                };

                // Must be a directory
                if (entry.entry_type != afs.ENTRY_TYPE_DIR) {
                    return null;
                }

                cluster = entry.first_cluster;
            }
            start = i + 1;
        }
    }

    return cluster;
}
