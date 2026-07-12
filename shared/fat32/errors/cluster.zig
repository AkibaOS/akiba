//! FAT32 Cluster Errors

pub const ClusterError = error{
    InvalidCluster,
    BadCluster,
    ReadFailed,
};
