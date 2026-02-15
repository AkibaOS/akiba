//! Location utilities - Resolve locations to AFS clusters

const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");

/// Resolve a location to its stack cluster
pub fn resolve_to_cluster(
    fs: *afs.AFS(ahci.BlockDevice),
    location: []const u8,
    current_cluster: u64,
) ?u32 {
    const current: u32 = if (current_cluster == 0) fs.root_cluster else @as(u32, @intCast(current_cluster));

    if (location.len == 0) {
        return current;
    }

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

    if (start >= location.len) {
        return cluster;
    }

    var i: usize = start;
    while (i <= location.len) : (i += 1) {
        const is_end = (i == location.len);
        const is_slash = !is_end and location[i] == '/';

        if (is_slash or is_end) {
            if (i > start) {
                const component = location[start..i];

                if (component.len == 1 and component[0] == '^') {
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
