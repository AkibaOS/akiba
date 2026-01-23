//! GPT Partition Table Parser for AFS

const serial = @import("../drivers/serial.zig");
const std = @import("std");

pub const Partition = struct {
    start_lba: u64,
    end_lba: u64,
    name: [36]u16,
};

pub fn find_afs_partition(device: anytype) ?Partition {
    // Read GPT header (sector 1)
    var gpt_header: [512]u8 align(16) = undefined;
    if (!device.read_sector(1, &gpt_header)) {
        return null;
    }

    // Verify GPT signature
    if (!std.mem.eql(u8, gpt_header[0..8], "EFI PART")) {
        return null;
    }

    // Get partition entry array location
    const partition_entry_lba = read_u64_le(gpt_header[72..80]);

    // Read partition entries (sector 2)
    var entries_sector: [512]u8 align(16) = undefined;
    if (!device.read_sector(partition_entry_lba, &entries_sector)) {
        return null;
    }

    // AFS partition GUID: A1B2C3D4-E5F6-0718-293A-4B5C6D7E8F90
    const afs_guid = [_]u8{ 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6, 0x07, 0x18, 0x29, 0x3A, 0x4B, 0x5C, 0x6D, 0x7E, 0x8F, 0x90 };

    // Check first 4 partition entries
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const entry_offset = i * 128;
        const type_guid = entries_sector[entry_offset .. entry_offset + 16];

        // Check if this is AFS partition
        if (std.mem.eql(u8, type_guid, &afs_guid)) {
            const start_lba = read_u64_le(entries_sector[entry_offset + 32 .. entry_offset + 40]);
            const end_lba = read_u64_le(entries_sector[entry_offset + 40 .. entry_offset + 48]);

            var partition: Partition = undefined;
            partition.start_lba = start_lba;
            partition.end_lba = end_lba;

            return partition;
        }
    }

    return null;
}

fn read_u64_le(bytes: []const u8) u64 {
    return @as(u64, bytes[0]) |
        (@as(u64, bytes[1]) << 8) |
        (@as(u64, bytes[2]) << 16) |
        (@as(u64, bytes[3]) << 24) |
        (@as(u64, bytes[4]) << 32) |
        (@as(u64, bytes[5]) << 40) |
        (@as(u64, bytes[6]) << 48) |
        (@as(u64, bytes[7]) << 56);
}
