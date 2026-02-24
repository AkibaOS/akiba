//! AFS cluster operations

const endian = @import("../../utils/bytes/endian.zig");
const fs = @import("../../common/constants/fs.zig");

pub fn is_valid(cluster: u32) bool {
    return cluster >= fs.CLUSTER_MIN and cluster < fs.CLUSTER_END;
}

pub fn to_lba(afs: anytype, cluster: u32) u64 {
    return afs.partition_offset + afs.data_area_sector + (cluster - fs.CLUSTER_MIN);
}

pub fn get_next(afs: anytype, cluster: u32) !u32 {
    const entry_offset = cluster * 4;
    const table_sector = afs.partition_offset + afs.alloc_table_sector + (entry_offset / afs.bytes_per_sector);
    const offset = entry_offset % afs.bytes_per_sector;

    var sector: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
    if (!afs.device.read_sector(table_sector, &sector)) {
        return error.ReadFailed;
    }

    return endian.read_u32_le(sector[offset..]);
}

pub fn write_alloc(afs: anytype, cluster: u32, value: u32) !void {
    const entry_offset = cluster * 4;
    const table_sector = afs.partition_offset + afs.alloc_table_sector + (entry_offset / afs.bytes_per_sector);
    const offset = entry_offset % afs.bytes_per_sector;

    var sector: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
    if (!afs.device.read_sector(table_sector, &sector)) {
        return error.ReadFailed;
    }

    endian.write_u32_le(sector[offset..], value);

    if (!afs.device.write_sector(table_sector, &sector)) {
        return error.WriteFailed;
    }
}

pub fn allocate(afs: anytype) !u32 {
    var cluster: u32 = fs.CLUSTER_MIN;

    while (cluster < afs.total_clusters) : (cluster += 1) {
        const entry_offset = cluster * 4;
        const table_sector = afs.partition_offset + afs.alloc_table_sector + (entry_offset / afs.bytes_per_sector);
        const offset = entry_offset % afs.bytes_per_sector;

        var sector: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
        if (!afs.device.read_sector(table_sector, &sector)) {
            return error.ReadFailed;
        }

        if (endian.read_u32_le(sector[offset..]) == fs.CLUSTER_FREE) {
            try write_alloc(afs, cluster, fs.CLUSTER_END);
            afs.increment_used();
            return cluster;
        }
    }

    return error.DiskFull;
}

pub fn free(afs: anytype, cluster: u32) !void {
    try write_alloc(afs, cluster, fs.CLUSTER_FREE);
    afs.decrement_used();
}
