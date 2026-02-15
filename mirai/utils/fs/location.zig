//! Location utilities

const afs = @import("../../fs/afs/afs.zig");
const ahci = @import("../../drivers/ahci/ahci.zig");
const compare = @import("../string/compare.zig");
const fs_limits = @import("../../common/limits/fs.zig");

pub fn resolve_to_cluster(
    fs: *afs.AFS(ahci.BlockDevice),
    location: []const u8,
    current_cluster: u64,
) ?u32 {
    const current: u32 = if (current_cluster == 0) fs.root_cluster else @as(u32, @intCast(current_cluster));

    if (location.len == 0) return current;

    if (location.len == 1 and location[0] == '^') {
        return fs.get_parent_cluster(current) orelse fs.root_cluster;
    }

    var cluster: u32 = undefined;
    var start: usize = 0;

    if (location[0] == '/') {
        cluster = fs.root_cluster;
        start = 1;
    } else {
        cluster = current;
    }

    if (start >= location.len) return cluster;

    var i: usize = start;
    while (i <= location.len) : (i += 1) {
        const is_end = (i == location.len);
        const is_slash = !is_end and location[i] == '/';

        if (is_slash or is_end) {
            if (i > start) {
                const component = location[start..i];

                if (compare.equals(component, "^")) {
                    cluster = fs.get_parent_cluster(cluster) orelse fs.root_cluster;
                } else {
                    const entry = fs.find_entry(cluster, component) orelse return null;
                    if (!entry.is_stack()) return null;
                    cluster = entry.first_cluster;
                }
            }
            start = i + 1;
        }
    }

    return cluster;
}

pub const Canonical = struct {
    buf: [fs_limits.MAX_LOCATION_LENGTH]u8,
    len: usize,

    pub fn slice(self: *const Canonical) []const u8 {
        return self.buf[0..self.len];
    }
};

pub fn canonicalize(current: []const u8, location: []const u8) Canonical {
    var result: Canonical = .{ .buf = undefined, .len = 0 };

    if (location.len == 1 and location[0] == '^') {
        @memcpy(result.buf[0..current.len], current);
        result.len = current.len;
        strip_last(&result);
        return result;
    }

    if (location.len > 0 and location[0] == '/') {
        result.buf[0] = '/';
        result.len = 1;
        process_components(&result, location[1..]);
        return result;
    }

    @memcpy(result.buf[0..current.len], current);
    result.len = current.len;
    process_components(&result, location);

    return result;
}

fn strip_last(result: *Canonical) void {
    if (result.len > 1) {
        result.len -= 1;
        while (result.len > 1 and result.buf[result.len - 1] != '/') {
            result.len -= 1;
        }
        if (result.len > 1) result.len -= 1;
    }
    if (result.len == 0) {
        result.buf[0] = '/';
        result.len = 1;
    }
}

fn process_components(result: *Canonical, location: []const u8) void {
    var i: usize = 0;
    while (i < location.len) {
        while (i < location.len and location[i] == '/') : (i += 1) {}
        if (i >= location.len) break;

        const start = i;
        while (i < location.len and location[i] != '/') : (i += 1) {}
        const component = location[start..i];

        if (compare.equals(component, "^")) {
            strip_last(result);
        } else {
            if (result.len > 1) {
                result.buf[result.len] = '/';
                result.len += 1;
            }
            for (component) |c| {
                if (result.len < fs_limits.MAX_LOCATION_LENGTH) {
                    result.buf[result.len] = c;
                    result.len += 1;
                }
            }
        }
    }
}
