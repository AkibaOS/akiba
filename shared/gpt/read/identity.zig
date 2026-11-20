//! Match The Handed Off AFS Identity Against Checked GPT Bytes

const std = @import("std");

const bounds = @import("shared").boot.constants.volume;
const fields = @import("shared").gpt.constants.read.entry;
const header = @import("shared").gpt.read.header;

const VerifyError = @import("shared").gpt.errors.read.verification.VerifyError;
const Volume = @import("shared").boot.types.volume.Volume;

pub fn match(volume: Volume, primary: []const u8, disk_last_lba: u64, table: []const u8) VerifyError!bool {
    if (!volume.isValid() or volume.DiskLastLBA != disk_last_lba or volume.BlockBytes != primary.len) return false;
    const window = try header.inspect(primary, disk_last_lba);
    if (!std.mem.eql(u8, &volume.DiskGUID, &window.DiskGUID)) return false;
    if (window.TableBytes > table.len) return error.InvalidTable;
    const entries = table[0..@intCast(window.TableBytes)];
    if (std.hash.Crc32.hash(entries) != window.TableCRC) return error.TableChecksum;

    const stride: usize = window.EntryBytes;
    var offset: usize = 0;
    var found = false;
    var matched = false;
    while (offset < entries.len) : (offset += stride) {
        const entry = entries[offset..][0..stride];
        const kind = entry[fields.TYPE_OFFSET..][0..bounds.GUID_BYTES];
        const guid = entry[fields.IDENTITY_OFFSET..][0..bounds.GUID_BYTES];
        if (std.mem.allEqual(u8, kind, 0) or !std.mem.eql(u8, guid, &volume.PartitionGUID)) continue;
        if (found) return error.AmbiguousPartition;
        found = true;
        const first = std.mem.readInt(u64, entry[fields.FIRST_OFFSET..][0..@sizeOf(u64)], .little);
        const last = std.mem.readInt(u64, entry[fields.LAST_OFFSET..][0..@sizeOf(u64)], .little);
        matched = first >= window.FirstUsableLBA and last <= window.LastUsableLBA and
            first == volume.FirstLBA and last == volume.LastLBA and std.mem.eql(u8, kind, &fields.AFS_TYPE_GUID);
    }
    return matched;
}
