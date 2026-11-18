//! Real Hikari GPT Parser Acquisition Regressions

const constants = @import("tests").constants.acquisition;
const errors = @import("hikari").disk.errors.gpt;
const fixture = @import("tests").guest.hikari.disk.fixture;
const labels = @import("tests").strings.acquisition;
const parser = @import("hikari").disk.types.parser;
const verify = @import("tests").verify;

const ParseError = errors.ParseError;
const Parser = parser.Parser;

pub fn run() !void {
    try validTable();
    try expandedTable(constants.BLOCK_BYTES, constants.LARGE_ENTRY_COUNT, labels.GPT_COUNT);
    try expandedTable(constants.LARGE_BLOCK_BYTES, constants.ENTRY_COUNT, labels.GPT_BLOCK);
    checksums();
    headerBounds();
    entryBounds();
    readFailures();
    mediaChanges();
    allocationFailures();
}

fn validTable() !void {
    fixture.reset();
    fixture.encodeGPT();
    var parsed: Parser = .{ .BootServices = &fixture.services };
    try parsed.initialize(&fixture.protocol);
    defer if (!parsed.deinitialize()) verify.failure(error.ReleaseFailed);
    const first = parsed.findPartitionByType(constants.TYPE_A);
    const second = parsed.findPartitionByType(constants.TYPE_B);
    const valid = first != null and first.?.StartingLBA == 8 and first.?.EndingLBA == 15 and
        second != null and second.?.StartingLBA == constants.PARTITION_FIRST_LBA and
        second.?.EndingLBA == constants.PARTITION_LAST_LBA and second.?.sizeInBlocks() == constants.VOLUME_CELLS and
        parsed.findPartitionByIndex(1) == null and parsed.findPartitionByIndex(3) == null and
        parsed.findPartitionByIndex(constants.ENTRY_COUNT) == null and
        parsed.countValidPartitions() == 2 and parsed.EntriesCount == constants.ENTRY_COUNT and
        parsed.EntrySize == constants.ENTRY_BYTES and parsed.getDiskGUID().equals(constants.DISK_GUID) and
        parsed.getFirstUsableLBA() == constants.FIRST_USABLE_LBA and parsed.getLastUsableLBA() == constants.LAST_USABLE_LBA and
        @intFromPtr(parsed.Scratch.Data) % constants.IO_ALIGNMENT == 0 and
        fixture.device.ReadCalls == 2 and fixture.device.Reads[0].LBA == constants.HEADER_LBA and
        fixture.device.Reads[1].LBA == constants.TABLE_LBA and fixture.device.Reads[1].Bytes == constants.TABLE_READ_BYTES and
        fixture.live() == 1;
    if (!parsed.deinitialize()) verify.failure(error.ReleaseFailed);
    if (!parsed.deinitialize()) verify.failure(error.ReleaseFailed);
    verify.require(valid and fixture.device.AllocateCalls == 2 and fixture.device.FreeCalls == 2 and fixture.clean(), labels.GPT_VALID);
}

fn expandedTable(block_size: u32, count: u32, comptime label: []const u8) !void {
    fixture.reset();
    fixture.encodeExpandedGPT(block_size, count);
    var parsed: Parser = .{ .BootServices = &fixture.services };
    try parsed.initialize(&fixture.protocol);
    const last = parsed.findPartitionByIndex(count - 1);
    const valid = parsed.EntriesCount == count and parsed.Media.BlockSize == block_size and
        last != null and last.?.isType(constants.TYPE_B) and
        parsed.findPartitionByType(constants.TYPE_B) == last and parsed.countValidPartitions() == 1 and
        parsed.findPartitionByIndex(count) == null and fixture.device.ReadCalls == 2 and fixture.live() == 1;
    if (!parsed.deinitialize()) verify.failure(error.ReleaseFailed);
    verify.require(valid and fixture.clean(), label);
    fixture.reset();
    fixture.encodeExpandedGPT(block_size, count);
    fixture.device.FailAllocation = 2;
    verify.require(rejects(ParseError.AllocationFailed, 2, 1, 1), labels.GPT_EXPANDED_PRESSURE);
    fixture.reset();
    fixture.encodeExpandedGPT(block_size, count);
    fixture.device.FailLBA = constants.TABLE_LBA;
    verify.require(rejects(ParseError.ReadFailed, 2, 2, 2), labels.GPT_EXPANDED_READ);
}

fn checksums() void {
    fixture.reset();
    fixture.encodeGPT();
    fixture.headerBytes()[56] ^= 1;
    const header_rejected = rejects(ParseError.InvalidHeaderCRC, 1, 1, 1);
    fixture.reset();
    fixture.encodeGPT();
    fixture.tableBytes()[0] ^= 1;
    verify.require(header_rejected and rejects(ParseError.InvalidEntriesCRC, 2, 2, 2), labels.GPT_CRC);
}

fn headerBounds() void {
    fixture.reset();
    fixture.encodeGPT();
    fixture.headerBytes()[0] = 0;
    const signature = rejects(ParseError.InvalidSignature, 1, 1, 1);
    fixture.reset();
    fixture.encodeGPT();
    fixture.writeU32(fixture.headerBytes(), 8, 0);
    fixture.sealHeader();
    const revision = rejects(ParseError.InvalidRevision, 1, 1, 1);
    fixture.reset();
    fixture.encodeGPT();
    fixture.writeU32(fixture.headerBytes(), 12, constants.HEADER_BYTES - 1);
    const short = rejects(ParseError.InvalidHeaderSize, 1, 1, 1);
    fixture.reset();
    fixture.encodeGPT();
    fixture.writeU32(fixture.headerBytes(), 12, constants.BLOCK_BYTES + 1);
    verify.require(signature and revision and short and rejects(ParseError.InvalidHeaderSize, 1, 1, 1), labels.GPT_HEADER);
}

fn entryBounds() void {
    fixture.reset();
    fixture.encodeGPT();
    fixture.writeU32(fixture.headerBytes(), 80, 0);
    fixture.sealHeader();
    const empty = rejects(ParseError.NoPartitions, 1, 1, 1);
    fixture.reset();
    fixture.encodeGPT();
    fixture.writeU32(fixture.headerBytes(), 80, constants.LARGE_ENTRY_COUNT);
    fixture.sealHeader();
    const excessive = rejects(ParseError.InvalidLayout, 1, 1, 1);
    fixture.reset();
    fixture.encodeGPT();
    fixture.writeU32(fixture.headerBytes(), 84, 120);
    fixture.sealHeader();
    const undersized = rejects(ParseError.InvalidLayout, 1, 1, 1);
    fixture.reset();
    fixture.encodeGPT();
    fixture.writeU64(fixture.headerBytes(), 72, constants.FIRST_USABLE_LBA);
    fixture.sealHeader();
    verify.require(empty and excessive and undersized and rejects(ParseError.InvalidLayout, 1, 1, 1), labels.GPT_LAYOUT);
}

fn readFailures() void {
    fixture.reset();
    fixture.encodeGPT();
    fixture.device.FailLBA = constants.HEADER_LBA;
    const header = rejects(ParseError.ReadFailed, 1, 1, 1);
    fixture.reset();
    fixture.encodeGPT();
    fixture.device.FailLBA = constants.TABLE_LBA;
    verify.require(header and rejects(ParseError.ReadFailed, 2, 2, 2), labels.GPT_READ_FAILURE);
}

fn mediaChanges() void {
    fixture.reset();
    fixture.encodeGPT();
    var replacement = fixture.media;
    replacement.MediaId += 1;
    fixture.changeMediaAfterRead(constants.HEADER_LBA, replacement);
    const replaced = rejects(ParseError.ReadFailed, 1, 1, 1);

    fixture.reset();
    fixture.encodeGPT();
    replacement = fixture.media;
    replacement.IOAlign = 1;
    fixture.changeMediaAfterRead(constants.TABLE_LBA, replacement);
    verify.require(replaced and rejects(ParseError.ReadFailed, 2, 2, 2), labels.GPT_MEDIA);
}

fn allocationFailures() void {
    fixture.reset();
    fixture.encodeGPT();
    fixture.device.FailAllocation = 1;
    const header = rejects(ParseError.AllocationFailed, 1, 0, 0);
    fixture.reset();
    fixture.encodeGPT();
    fixture.device.FailAllocation = 2;
    verify.require(header and rejects(ParseError.AllocationFailed, 2, 1, 1), labels.GPT_POOL_FAILURE);
}

fn rejects(expected: ParseError, allocations: usize, frees: usize, reads: usize) bool {
    var parsed: Parser = .{ .BootServices = &fixture.services };
    const refused = if (parsed.initialize(&fixture.protocol)) |_| false else |failure| failure == expected;
    return parsed.deinitialize() and refused and fixture.device.AllocateCalls == allocations and
        fixture.device.FreeCalls == frees and fixture.device.ReadCalls == reads and fixture.clean();
}
