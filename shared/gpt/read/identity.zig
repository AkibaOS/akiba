//! Verify The Handed Off AFS Identity From Bytes Or Sectors

const std = @import("std");

const fields = @import("shared").gpt.constants.read.header;
const header = @import("shared").gpt.read.header;
const table = @import("shared").gpt.read.table;

const Scan = @import("shared").gpt.types.read.scan.Scan;
const Source = @import("shared").gpt.types.read.source.Source;
const VerifyError = @import("shared").gpt.errors.read.verification.VerifyError;
const Volume = @import("shared").boot.types.volume.Volume;

pub fn match(volume: Volume, primary: []const u8, disk_last_lba: u64, bytes: []const u8) VerifyError!bool {
    if (!sameGeometry(volume, primary.len, disk_last_lba)) return false;
    var scan = (try begin(volume, primary, disk_last_lba)) orelse return false;
    if (scan.Remaining > bytes.len) return error.InvalidTable;
    try table.append(&scan, bytes[0..@intCast(scan.Remaining)]);
    return table.finish(&scan);
}

pub fn matchSectors(volume: Volume, source: Source, scratch: []u8) anyerror!bool {
    if (!sameGeometry(volume, source.BlockBytes, source.LastLBA)) return false;
    if (source.BlockBytes > scratch.len) return error.InvalidSource;
    const block = scratch[0..source.BlockBytes];
    try source.Read(source.Context, fields.PRIMARY_LBA, block);
    var scan = (try begin(volume, block, source.LastLBA)) orelse return false;
    var offset: u64 = 0;
    while (offset < scan.Window.TableSectors) : (offset += 1) {
        try source.Read(source.Context, scan.Window.TableLBA + offset, block);
        const count: usize = @intCast(@min(scan.Remaining, block.len));
        try table.append(&scan, block[0..count]);
    }
    return table.finish(&scan);
}

fn sameGeometry(volume: Volume, block_bytes: usize, disk_last_lba: u64) bool {
    return volume.isValid() and volume.BlockBytes == block_bytes and volume.DiskLastLBA == disk_last_lba;
}

fn begin(volume: Volume, primary: []const u8, disk_last_lba: u64) VerifyError!?Scan {
    const window = try header.inspect(primary, disk_last_lba);
    if (!std.mem.eql(u8, &volume.DiskGUID, &window.DiskGUID)) return null;
    return .{ .Volume = volume, .Window = window, .Remaining = window.TableBytes };
}
