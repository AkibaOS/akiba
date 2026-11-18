//! Real Hikari AFS Unit Acquisition Boundary Regressions

const std = @import("std");

const afs = @import("shared").afs;
const constants = @import("tests").constants.acquisition;
const errors = @import("hikari").fs.errors.afs;
const fixture = @import("tests").guest.hikari.disk.fixture;
const labels = @import("tests").strings.acquisition;
const media = @import("hikari").disk.types.media;
const reader = @import("hikari").fs.types.afs.reader;
const status = @import("hikari").efi.constants.status;
const verify = @import("tests").verify;

const ReadError = errors.ReadError;
const Reader = reader.Reader;
const UnitRecord = afs.types.catalog.UnitRecord;

pub fn run() !void {
    try acquire();
    try rejectBeforeAllocation();
    try malformedSpans();
    try readFailure();
    try changedGeometry();
}

fn initialize() !Reader {
    fixture.reset();
    fixture.encodeAFS();
    const snapshot = media.MediaSnapshot.capture(&fixture.protocol) orelse return ReadError.ReadFailed;
    return Reader.initialize(snapshot, &fixture.services, constants.PARTITION_FIRST_LBA, constants.PARTITION_LAST_LBA);
}

fn acquire() !void {
    var source = try initialize();
    defer source.deinitialize();
    const record = fixture.unit();
    const bytes = try source.readUnitToAllocated(&record, constants.UNIT_LIMIT);
    const valid = bytes.Size == constants.UNIT_PAYLOAD.len and
        std.mem.eql(u8, bytes.Buffer[0..bytes.Size], &constants.UNIT_PAYLOAD) and
        fixture.device.Requested[fixture.device.AllocateCalls - 1] == constants.UNIT_PAYLOAD.len and
        fixture.device.ReadCalls == 3 and fixture.device.Reads[2].LBA == constants.PARTITION_FIRST_LBA + constants.PAYLOAD_CELL and
        fixture.device.Reads[2].Bytes == constants.BLOCK_BYTES and fixture.live() == 3;
    const released = fixture.services.FreePool(@alignCast(bytes.Buffer));
    source.deinitialize();
    source.deinitialize();
    verify.require(valid and released == status.SUCCESS and fixture.device.AllocateCalls == fixture.device.FreeCalls and
        fixture.clean(), labels.UNIT_VALID);
}

fn rejectBeforeAllocation() !void {
    var source = try initialize();
    defer source.deinitialize();
    const allocations = fixture.device.AllocateCalls;
    const frees = fixture.device.FreeCalls;
    const reads = fixture.device.ReadCalls;
    const empty: UnitRecord = .{};
    const empty_rejected = rejects(&source, &empty, constants.UNIT_LIMIT, ReadError.UnitTooLarge);
    var oversized = fixture.unit();
    oversized.DataChannel.LogicalSize = constants.UNIT_PAYLOAD.len + 1;
    const caller_limit = rejects(&source, &oversized, constants.UNIT_PAYLOAD.len, ReadError.UnitTooLarge);
    oversized.DataChannel.LogicalSize = @as(u64, constants.VOLUME_CELLS) * constants.BLOCK_BYTES + 1;
    oversized.DataChannel.PhysicalSize = oversized.DataChannel.LogicalSize;
    oversized.DataChannel.TotalCells = constants.VOLUME_CELLS + 1;
    oversized.DataChannel.Spans[0].CellCount = constants.VOLUME_CELLS + 1;
    const volume_limit = rejects(&source, &oversized, std.math.maxInt(u64), ReadError.UnitTooLarge);
    const untouched = fixture.device.AllocateCalls == allocations and fixture.device.FreeCalls == frees and
        fixture.device.ReadCalls == reads and fixture.live() == 2;
    source.deinitialize();
    verify.require(empty_rejected and caller_limit and volume_limit and untouched and fixture.clean(), labels.UNIT_PREALLOCATION);
}

fn malformedSpans() !void {
    var source = try initialize();
    defer source.deinitialize();
    const allocations = fixture.device.AllocateCalls;
    const frees = fixture.device.FreeCalls;
    const reads = fixture.device.ReadCalls;
    var record = fixture.unit();
    record.DataChannel.PhysicalSize = 0;
    const channel = rejects(&source, &record, constants.UNIT_LIMIT, ReadError.InvalidSpan) and
        fixture.device.AllocateCalls == allocations + 1 and fixture.device.FreeCalls == frees + 1;
    record = fixture.unit();
    record.DataChannel.Spans[0].StartCell = constants.VOLUME_CELLS;
    const span = rejects(&source, &record, constants.UNIT_LIMIT, ReadError.InvalidSpan);
    const rolled_back = fixture.device.AllocateCalls == allocations + 2 and fixture.device.FreeCalls == frees + 2 and
        fixture.device.ReadCalls == reads and fixture.live() == 2;
    source.deinitialize();
    verify.require(channel and span and rolled_back and fixture.clean(), labels.UNIT_SPAN_ROLLBACK);
}

fn readFailure() !void {
    var source = try initialize();
    defer source.deinitialize();
    const allocations = fixture.device.AllocateCalls;
    const frees = fixture.device.FreeCalls;
    const reads = fixture.device.ReadCalls;
    const record = fixture.unit();
    fixture.device.FailLBA = constants.PARTITION_FIRST_LBA + constants.PAYLOAD_CELL;
    const rejected = rejects(&source, &record, constants.UNIT_LIMIT, ReadError.ReadFailed);
    const rolled_back = fixture.device.AllocateCalls == allocations + 1 and fixture.device.FreeCalls == frees + 1 and
        fixture.device.ReadCalls == reads + 1 and fixture.device.Reads[reads].LBA == fixture.device.FailLBA and
        fixture.device.Reads[reads].Bytes == constants.BLOCK_BYTES and fixture.live() == 2;
    source.deinitialize();
    verify.require(rejected and rolled_back and fixture.device.AllocateCalls == fixture.device.FreeCalls and fixture.clean(), labels.UNIT_READ_FAILURE);
}

fn changedGeometry() !void {
    var source = try initialize();
    defer source.deinitialize();
    const reads = fixture.device.ReadCalls;
    const record = fixture.unit();
    fixture.media.LastBlock -= 1;
    const rejected = rejects(&source, &record, constants.UNIT_LIMIT, ReadError.ReadFailed) and
        fixture.device.ReadCalls == reads and fixture.live() == 2;
    source.deinitialize();
    verify.require(rejected and fixture.device.AllocateCalls == fixture.device.FreeCalls and fixture.clean(), labels.UNIT_MEDIA);
}

fn rejects(source: *Reader, record: *const UnitRecord, maximum: u64, expected: ReadError) bool {
    const bytes = source.readUnitToAllocated(record, maximum) catch |failure| return failure == expected;
    _ = fixture.services.FreePool(@alignCast(bytes.Buffer));
    return false;
}
