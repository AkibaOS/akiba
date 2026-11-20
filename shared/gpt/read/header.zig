//! Validate A Primary GPT Header And Bound The Table Window

const std = @import("std");

const bounds = @import("shared").boot.constants.volume;
const entry = @import("shared").gpt.constants.read.entry;
const fields = @import("shared").gpt.constants.read.header;

const VerifyError = @import("shared").gpt.errors.read.verification.VerifyError;
const Window = @import("shared").gpt.types.read.window.Window;

pub fn inspect(block: []const u8, disk_last_lba: u64) VerifyError!Window {
    if (block.len < bounds.MINIMUM_BLOCK_BYTES or block.len > std.math.maxInt(u32) or !std.math.isPowerOfTwo(block.len) or
        disk_last_lba <= fields.PRIMARY_LBA) return error.InvalidHeader;
    const bytes = integer(u32, block, fields.SIZE_OFFSET);
    if (integer(u64, block, fields.SIGNATURE_OFFSET) != fields.SIGNATURE or
        integer(u32, block, fields.REVISION_OFFSET) < fields.MINIMUM_REVISION or
        bytes < fields.MINIMUM_BYTES or bytes > block.len) return error.InvalidHeader;
    if (checksum(block[0..bytes]) != integer(u32, block, fields.CRC_OFFSET)) return error.HeaderChecksum;

    const first_usable = integer(u64, block, fields.FIRST_USABLE_OFFSET);
    const last_usable = integer(u64, block, fields.LAST_USABLE_OFFSET);
    const disk_guid = block[fields.DISK_GUID_OFFSET..][0..bounds.GUID_BYTES].*;
    if (integer(u32, block, fields.RESERVED_OFFSET) != 0 or std.mem.allEqual(u8, &disk_guid, 0) or
        integer(u64, block, fields.CURRENT_OFFSET) != fields.PRIMARY_LBA or
        integer(u64, block, fields.ALTERNATE_OFFSET) != disk_last_lba or
        first_usable > last_usable or last_usable >= disk_last_lba) return error.InvalidHeader;

    const table_lba = integer(u64, block, fields.TABLE_LBA_OFFSET);
    const count = integer(u32, block, fields.ENTRY_COUNT_OFFSET);
    const stride = integer(u32, block, fields.ENTRY_BYTES_OFFSET);
    if (count == 0 or stride < entry.MINIMUM_BYTES or stride % entry.STRIDE_ALIGNMENT != 0 or
        table_lba < fields.MINIMUM_TABLE_LBA or table_lba >= first_usable) return error.InvalidTable;
    const table_bytes = @as(u64, count) * stride;
    const sectors = (table_bytes - 1) / @as(u64, @intCast(block.len)) + 1;
    if (sectors > first_usable - table_lba or sectors > disk_last_lba - last_usable - 1) return error.InvalidTable;

    return .{
        .DiskGUID = disk_guid,
        .FirstUsableLBA = first_usable,
        .LastUsableLBA = last_usable,
        .TableLBA = table_lba,
        .TableBytes = table_bytes,
        .TableSectors = sectors,
        .TableCRC = integer(u32, block, fields.TABLE_CRC_OFFSET),
        .EntryBytes = stride,
    };
}

fn checksum(header: []const u8) u32 {
    var crc = std.hash.Crc32.init();
    crc.update(header[0..fields.CRC_OFFSET]);
    crc.update(&([_]u8{0} ** @sizeOf(u32)));
    crc.update(header[fields.CRC_OFFSET + @sizeOf(u32) ..]);
    return crc.final();
}

fn integer(comptime Value: type, bytes: []const u8, comptime offset: usize) Value {
    return std.mem.readInt(Value, bytes[offset..][0..@sizeOf(Value)], .little);
}
