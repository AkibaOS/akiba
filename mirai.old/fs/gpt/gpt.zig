//! GPT Partition Table Parser

const compare = @import("../../utils/string/compare.zig");
const endian = @import("../../utils/bytes/endian.zig");
const fs = @import("../../common/constants/fs.zig");
const types = @import("types.zig");

pub const Partition = types.Partition;

pub fn find_afs_partition(device: anytype) ?Partition {
    var header: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
    if (!device.read_sector(fs.GPT_HEADER_SECTOR, &header)) {
        return null;
    }

    if (!compare.equals_bytes(header[0..8], fs.GPT_SIGNATURE)) {
        return null;
    }

    const partition_lba = endian.read_u64_le(header[fs.GPT_HEADER_PARTITION_LBA_OFFSET..]);

    var entries: [fs.SECTOR_SIZE]u8 align(fs.SECTOR_ALIGN) = undefined;
    if (!device.read_sector(partition_lba, &entries)) {
        return null;
    }

    var i: usize = 0;
    while (i < fs.GPT_PARTITION_ENTRIES_MAX) : (i += 1) {
        const offset = i * fs.GPT_ENTRY_SIZE;
        const type_guid = entries[offset .. offset + fs.GPT_ENTRY_TYPE_GUID_SIZE];

        if (compare.equals_bytes(type_guid, &fs.AFS_PARTITION_GUID)) {
            return Partition{
                .start_lba = endian.read_u64_le(entries[offset + fs.GPT_ENTRY_START_LBA_OFFSET ..]),
                .end_lba = endian.read_u64_le(entries[offset + fs.GPT_ENTRY_END_LBA_OFFSET ..]),
            };
        }
    }

    return null;
}
