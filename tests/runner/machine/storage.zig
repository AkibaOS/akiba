//! Create One Disposable Read Only Secondary Data Disk

const std = @import("std");

const fixture = @import("tests").phase.constants.storage;

pub fn create(path: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{ .exclusive = true });
    defer file.close();
    try file.setEndPos((fixture.LAST_LBA + 1) * fixture.BLOCK_BYTES);
    var header: [fixture.BLOCK_BYTES]u8 = @splat(0);
    var entries: [fixture.ENTRY_COUNT * fixture.ENTRY_BYTES]u8 = @splat(0);
    @memcpy(header[0..8], &fixture.SIGNATURE);
    std.mem.writeInt(u32, header[8..12], fixture.REVISION, .little);
    std.mem.writeInt(u32, header[12..16], fixture.HEADER_BYTES, .little);
    std.mem.writeInt(u64, header[24..32], 1, .little);
    std.mem.writeInt(u64, header[32..40], fixture.LAST_LBA, .little);
    std.mem.writeInt(u64, header[40..48], fixture.FIRST_USABLE, .little);
    std.mem.writeInt(u64, header[48..56], fixture.LAST_USABLE, .little);
    @memcpy(header[56..72], &fixture.DISK_GUID);
    std.mem.writeInt(u64, header[72..80], fixture.TABLE_LBA, .little);
    std.mem.writeInt(u32, header[80..84], fixture.ENTRY_COUNT, .little);
    std.mem.writeInt(u32, header[84..88], fixture.ENTRY_BYTES, .little);
    @memcpy(entries[0..16], &fixture.AFS_TYPE);
    @memcpy(entries[16..32], &fixture.PARTITION_GUID);
    std.mem.writeInt(u64, entries[32..40], fixture.FIRST, .little);
    std.mem.writeInt(u64, entries[40..48], fixture.LAST, .little);
    std.mem.writeInt(u32, header[88..92], std.hash.Crc32.hash(&entries), .little);
    std.mem.writeInt(u32, header[16..20], std.hash.Crc32.hash(header[0..fixture.HEADER_BYTES]), .little);
    try file.pwriteAll(&header, fixture.BLOCK_BYTES);
    try file.pwriteAll(&entries, fixture.TABLE_LBA * fixture.BLOCK_BYTES);
    try file.pwriteAll(&([_]u8{fixture.SENTINEL} ** fixture.BLOCK_BYTES), fixture.FIRST * fixture.BLOCK_BYTES);
}
