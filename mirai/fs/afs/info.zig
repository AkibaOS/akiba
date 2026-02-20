//! AFS disk info operations

const endian = @import("../../utils/bytes/endian.zig");
const fs = @import("../../common/constants/fs.zig");
const types = @import("types.zig");

pub fn get_disk_info(afs: anytype) types.DiskInfo {
    const cluster_size: u64 = @as(u64, afs.sectors_per_cluster) * fs.SECTOR_SIZE;
    const total = @as(u64, afs.total_clusters) * cluster_size;

    // Count used clusters by scanning allocation table in bulk
    var used_clusters: u64 = 0;
    var sector_buf: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;

    const entries_per_sector = fs.SECTOR_SIZE / 4; // 4 bytes per entry
    const table_sectors = (afs.total_clusters + entries_per_sector - 1) / entries_per_sector;

    var sector_idx: u32 = 0;
    while (sector_idx < table_sectors) : (sector_idx += 1) {
        const table_sector = afs.partition_offset + afs.alloc_table_sector + sector_idx;

        if (!afs.device.read_sector(table_sector, &sector_buf)) {
            break;
        }

        // Count non-free entries in this sector
        var entry_idx: usize = 0;
        while (entry_idx < entries_per_sector) : (entry_idx += 1) {
            const cluster = sector_idx * entries_per_sector + entry_idx;
            if (cluster >= afs.total_clusters) break;
            if (cluster < fs.CLUSTER_MIN) {
                entry_idx += 1;
                continue;
            }

            const offset = entry_idx * 4;
            const value = endian.read_u32_le(sector_buf[offset..]);

            if (value != fs.CLUSTER_FREE) {
                used_clusters += 1;
            }
        }
    }

    return types.DiskInfo{
        .total_bytes = total,
        .used_bytes = used_clusters * cluster_size,
    };
}
