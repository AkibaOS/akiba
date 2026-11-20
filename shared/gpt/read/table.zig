//! Accumulate GPT Table Integrity And Partition Identity Evidence

const std = @import("std");

const bounds = @import("shared").boot.constants.volume;
const fields = @import("shared").gpt.constants.read.entry;

const Scan = @import("shared").gpt.types.read.scan.Scan;
const VerifyError = @import("shared").gpt.errors.read.verification.VerifyError;

pub fn append(scan: *Scan, bytes: []const u8) VerifyError!void {
    const stride: usize = scan.Window.EntryBytes;
    if (stride < fields.PREFIX_BYTES or scan.Offset >= stride or bytes.len > scan.Remaining) return error.InvalidTable;
    scan.CRC.update(bytes);
    scan.Remaining -= bytes.len;
    var remaining = bytes;
    while (remaining.len != 0) {
        const count = @min(remaining.len, stride - scan.Offset);
        if (scan.Offset < scan.Prefix.len) {
            const prefix_bytes = @min(count, scan.Prefix.len - scan.Offset);
            const end = scan.Offset + prefix_bytes;
            @memcpy(scan.Prefix[scan.Offset..end], remaining[0..prefix_bytes]);
            if (end == scan.Prefix.len) observe(scan);
        }
        scan.Offset += count;
        if (scan.Offset == stride) scan.Offset = 0;
        remaining = remaining[count..];
    }
}

pub fn finish(scan: *const Scan) VerifyError!bool {
    if (scan.Remaining != 0 or scan.Offset != 0) return error.InvalidTable;
    if (scan.CRC.final() != scan.Window.TableCRC) return error.TableChecksum;
    if (scan.Match == .Ambiguous) return error.AmbiguousPartition;
    return scan.Match == .Matched;
}

fn observe(scan: *Scan) void {
    const entry = &scan.Prefix;
    const kind = entry[fields.TYPE_OFFSET..][0..bounds.GUID_BYTES];
    const guid = entry[fields.IDENTITY_OFFSET..][0..bounds.GUID_BYTES];
    if (std.mem.allEqual(u8, kind, 0) or !std.mem.eql(u8, guid, &scan.Volume.PartitionGUID)) return;
    if (scan.Match != .Missing) {
        scan.Match = .Ambiguous;
        return;
    }
    const first = std.mem.readInt(u64, entry[fields.FIRST_OFFSET..][0..@sizeOf(u64)], .little);
    const last = std.mem.readInt(u64, entry[fields.LAST_OFFSET..][0..@sizeOf(u64)], .little);
    const matches = first >= scan.Window.FirstUsableLBA and last <= scan.Window.LastUsableLBA and
        first == scan.Volume.FirstLBA and last == scan.Volume.LastLBA and std.mem.eql(u8, kind, &fields.AFS_TYPE_GUID);
    scan.Match = if (matches) .Matched else .Mismatch;
}
