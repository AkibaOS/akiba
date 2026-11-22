//! Discover One AFS Partition Through The Verified GPT Stream

const fields = @import("shared").gpt.constants.read.header;
const header = @import("shared").gpt.read.header;
const table = @import("shared").gpt.read.table;

const Scan = @import("shared").gpt.types.read.scan.Scan;
const Source = @import("shared").storage.types.sector.Source;
const Volume = @import("shared").boot.types.volume.Volume;

pub fn firstAfs(source: Source, scratch: []u8) !?Volume {
    if (source.BlockBytes > scratch.len) return error.InvalidSource;
    const block = scratch[0..source.BlockBytes];
    try source.Read(source.Context, fields.PRIMARY_LBA, block);
    const window = try header.inspect(block, source.LastLBA);
    var scan: Scan = .{
        .Volume = .{ .DiskGUID = window.DiskGUID, .PartitionGUID = @splat(0), .FirstLBA = 0, .LastLBA = 0, .DiskLastLBA = source.LastLBA, .BlockBytes = source.BlockBytes },
        .Window = window,
        .Remaining = window.TableBytes,
        .Discover = true,
    };
    var index: u64 = 0;
    while (index < window.TableSectors) : (index += 1) {
        try source.Read(source.Context, window.TableLBA + index, block);
        try table.append(&scan, block[0..@intCast(@min(scan.Remaining, block.len))]);
    }
    return if (try table.finish(&scan)) scan.Volume else null;
}
