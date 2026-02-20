//! AFS disk info operations

const fs = @import("../../common/constants/fs.zig");
const types = @import("types.zig");

pub fn get_disk_info(afs: anytype) types.DiskInfo {
    const cluster_size: u64 = @as(u64, afs.sectors_per_cluster) * fs.SECTOR_SIZE;
    const total = @as(u64, afs.total_clusters) * cluster_size;
    const used = @as(u64, afs.used_clusters) * cluster_size;

    return types.DiskInfo{
        .total_bytes = total,
        .used_bytes = used,
    };
}
