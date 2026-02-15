//! AFS parent cache operations

const types = @import("types.zig");

pub fn store(afs: anytype, child: u32, parent: u32) void {
    for (afs.parent_cache[0..afs.parent_cache_count]) |*e| {
        if (e.cluster == child) {
            e.parent = parent;
            return;
        }
    }

    if (afs.parent_cache_count < afs.parent_cache.len) {
        afs.parent_cache[afs.parent_cache_count] = types.ParentCacheEntry{
            .cluster = child,
            .parent = parent,
        };
        afs.parent_cache_count += 1;
    }
}

pub fn lookup(afs: anytype, cluster: u32) ?u32 {
    if (cluster == afs.root_cluster) return afs.root_cluster;

    for (afs.parent_cache[0..afs.parent_cache_count]) |e| {
        if (e.cluster == cluster) {
            return e.parent;
        }
    }

    return null;
}
