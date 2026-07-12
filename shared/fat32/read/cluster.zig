//! FAT32 Cluster Operations

const constants = @import("../constants/constants.zig");
const errors = @import("../errors/errors.zig");

const ClusterError = errors.cluster.ClusterError;

pub fn isValidCluster(cluster: u32) bool {
    return cluster >= constants.clusters.CLUSTER_DATA_START and
        cluster < constants.clusters.CLUSTER_EOC_START and
        cluster != constants.clusters.CLUSTER_BAD;
}

pub fn isEndOfChain(cluster: u32) bool {
    return (cluster & constants.clusters.CLUSTER_MASK) >= constants.clusters.CLUSTER_EOC_START;
}

pub fn getFatPosition(cluster: u32, bytes_per_sector: u32) struct { Sector: u32, Offset: u32 } {
    const fat_offset = cluster * @sizeOf(u32);
    return .{
        .Sector = fat_offset / bytes_per_sector,
        .Offset = fat_offset % bytes_per_sector,
    };
}

pub fn clusterToLba(
    cluster: u32,
    data_start_lba: u64,
    sectors_per_cluster: u32,
) u64 {
    return data_start_lba + (@as(u64, cluster - constants.clusters.CLUSTER_DATA_START) * sectors_per_cluster);
}

pub fn parseFatEntry(entry: u32) ClusterError!?u32 {
    const next = entry & constants.clusters.CLUSTER_MASK;

    if (isEndOfChain(next)) {
        return null;
    }
    if (next == constants.clusters.CLUSTER_BAD) {
        return ClusterError.BadCluster;
    }
    if (next < constants.clusters.CLUSTER_DATA_START) {
        return ClusterError.InvalidCluster;
    }

    return next;
}
