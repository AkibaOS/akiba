//! FAT32 Cluster Operations

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const BootSector = types.BootSector;

pub const ClusterError = error{
    InvalidCluster,
    BadCluster,
    ReadFailed,
};

pub fn is_valid_cluster(cluster: u32) bool {
    return cluster >= constants.cluster_data_start and
        cluster < constants.cluster_eoc_start and
        cluster != constants.cluster_bad;
}

pub fn is_end_of_chain(cluster: u32) bool {
    return (cluster & constants.cluster_mask) >= constants.cluster_eoc_start;
}

pub fn get_fat_position(cluster: u32, bytes_per_sector: u32) struct { sector: u32, offset: u32 } {
    const fat_offset = cluster * 4;
    return .{
        .sector = fat_offset / bytes_per_sector,
        .offset = fat_offset % bytes_per_sector,
    };
}

pub fn cluster_to_lba(
    cluster: u32,
    data_start_lba: u64,
    sectors_per_cluster: u32,
) u64 {
    return data_start_lba + (@as(u64, cluster - 2) * sectors_per_cluster);
}

pub fn parse_fat_entry(entry: u32) ClusterError!?u32 {
    const next = entry & constants.cluster_mask;

    if (is_end_of_chain(next)) {
        return null;
    }
    if (next == constants.cluster_bad) {
        return ClusterError.BadCluster;
    }
    if (next < constants.cluster_data_start) {
        return ClusterError.InvalidCluster;
    }

    return next;
}
