//! AFS Catalog Construction Checks

const std = @import("std");

const constants = @import("tests").fast.constants.storage;
const records = @import("shared").afs.write.stack;
const unit = @import("shared").afs.write.unit;
const volume = @import("shared").afs.types.volume;

pub fn spanAndChannelConstruction() !void {
    const span = volume.SpanDescriptor{ .StartCell = 3, .CellCount = 2 };
    try std.testing.expect(!span.isEmpty());
    try std.testing.expectEqual(@as(u64, 5), span.endCell());
    try std.testing.expectEqual(@as(u64, 1024), span.byteSize(constants.CELL_SIZE));
    try std.testing.expect(!span.contains(2));
    try std.testing.expect(span.contains(3));
    try std.testing.expect(span.contains(4));
    try std.testing.expect(!span.contains(5));
    const empty = volume.SpanDescriptor{ .StartCell = 3 };
    try std.testing.expect(empty.isEmpty());
    try std.testing.expect(!empty.contains(3));

    const channel = try unit.createChannelInfo(constants.CELL_SIZE + constants.PARTIAL_BYTES, 3, 2, constants.CELL_SIZE);
    var expected = volume.ChannelInfo{
        .LogicalSize = constants.CELL_SIZE + constants.PARTIAL_BYTES,
        .PhysicalSize = 1024,
        .ClumpSize = constants.CELL_SIZE,
        .TotalCells = 2,
    };
    expected.Spans[0] = .{ .StartCell = 3, .CellCount = 2 };
    try std.testing.expectEqualDeep(expected, channel);
    try std.testing.expectEqualDeep(span, channel.getSpan(0).?.*);
    try std.testing.expect(channel.getSpan(1) == null);
    try std.testing.expect(channel.getSpan(channel.Spans.len) == null);
    const empty_channel = try unit.createChannelInfo(0, 7, 0, constants.CELL_SIZE);
    try std.testing.expectEqualDeep(volume.ChannelInfo{ .ClumpSize = constants.CELL_SIZE }, empty_channel);
}

pub fn roundedCellCounts() !void {
    try std.testing.expectEqual(@as(u32, 0), try unit.cellsNeeded(0, constants.CELL_SIZE));
    try std.testing.expectEqual(@as(u32, 1), try unit.cellsNeeded(1, constants.CELL_SIZE));
    try std.testing.expectEqual(@as(u32, 1), try unit.cellsNeeded(511, constants.CELL_SIZE));
    try std.testing.expectEqual(@as(u32, 1), try unit.cellsNeeded(512, constants.CELL_SIZE));
    try std.testing.expectEqual(@as(u32, 2), try unit.cellsNeeded(513, constants.CELL_SIZE));
    try std.testing.expectEqual(@as(u32, 2), try unit.cellsNeeded(1024, constants.CELL_SIZE));
    try std.testing.expectEqual(@as(u32, 3), try unit.cellsNeeded(1025, constants.CELL_SIZE));
}

pub fn stackConstruction() !void {
    var stack = records.createStackRecord(33, 0x0102030405060708, 0o750);
    try std.testing.expectEqual(@as(u16, 1), stack.RecordType);
    try std.testing.expectEqual(@as(u16, 2), stack.Flags);
    try std.testing.expectEqual(@as(u32, 33), stack.NodeId);
    try std.testing.expectEqual(@as(u32, 0), stack.Valence);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), stack.CreationTimestamp);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), stack.ModificationTimestamp);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), stack.AttributeModificationTimestamp);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), stack.AccessTimestamp);
    try std.testing.expectEqual(@as(u64, 0), stack.BackupTimestamp);
    try std.testing.expectEqual(@as(u32, 0), stack.Permissions.OwnerId);
    try std.testing.expectEqual(@as(u32, 0), stack.Permissions.GroupId);
    try std.testing.expectEqual(@as(u8, 0), stack.Permissions.AdminFlags);
    try std.testing.expectEqual(@as(u8, 0), stack.Permissions.OwnerFlags);
    try std.testing.expectEqual(@as(u16, 0o750), stack.Permissions.Mode);
    try std.testing.expectEqual(@as(u32, 0), stack.Permissions.Special.InodeNumber);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 16), &stack.Special.Raw);
    try std.testing.expectEqual(@as(u32, 0), stack.TextEncoding);
    try std.testing.expectEqual(@as(u32, 0), stack.Reserved);
    try std.testing.expect(stack.isEmpty());
    stack.Valence = 1;
    try std.testing.expect(!stack.isEmpty());
}

pub fn unitConstruction() !void {
    var channel = volume.ChannelInfo{ .LogicalSize = 7, .PhysicalSize = constants.CELL_SIZE, .TotalCells = 1 };
    channel.Spans[0] = .{ .StartCell = 6, .CellCount = 1 };
    var record = records.createUnitRecord(34, 0x0102030405060708, 0o640, channel);
    try std.testing.expectEqual(@as(u16, 2), record.RecordType);
    try std.testing.expectEqual(@as(u16, 2), record.Flags);
    try std.testing.expectEqual(@as(u32, 34), record.NodeId);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), record.CreationTimestamp);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), record.ModificationTimestamp);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), record.AttributeModificationTimestamp);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), record.AccessTimestamp);
    try std.testing.expectEqual(@as(u64, 0), record.BackupTimestamp);
    try std.testing.expectEqual(@as(u32, 0), record.Permissions.OwnerId);
    try std.testing.expectEqual(@as(u32, 0), record.Permissions.GroupId);
    try std.testing.expectEqual(@as(u8, 0), record.Permissions.AdminFlags);
    try std.testing.expectEqual(@as(u8, 0), record.Permissions.OwnerFlags);
    try std.testing.expectEqual(@as(u16, 0o640), record.Permissions.Mode);
    try std.testing.expectEqual(@as(u32, 0), record.Permissions.Special.InodeNumber);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 16), &record.Special.Raw);
    try std.testing.expectEqual(@as(u32, 0), record.TextEncoding);
    try std.testing.expectEqual(@as(u32, 0), record.Reserved1);
    try std.testing.expectEqual(@as(u32, 0), record.Reserved2);
    try std.testing.expectEqualDeep(channel, record.DataChannel);
    try std.testing.expectEqualDeep(volume.ChannelInfo{}, record.ResourceChannel);
    try std.testing.expect(!record.hasResourceChannel());
    try std.testing.expect(!record.hasTwins());
    record.Flags |= 0x20;
    try std.testing.expect(record.hasResourceChannel());
    try std.testing.expect(!record.hasTwins());
    record.Flags |= 0x10;
    try std.testing.expect(record.hasTwins());
}

pub fn indexKeyConstruction() !void {
    const empty = try records.createIndexKey(7, "");
    try std.testing.expectEqual(@as(u16, 8), empty.KeyLength);
    try std.testing.expectEqual(@as(u32, 7), empty.ParentNodeId);
    try std.testing.expectEqual(@as(usize, 0), empty.getIdentityLength());
    try std.testing.expectEqualSlices(u16, &([_]u16{0} ** 256), &empty.Identity);
    const key = try records.createIndexKey(7, &.{ 'A', 0xe9 });
    try std.testing.expectEqual(@as(u16, 12), key.KeyLength);
    try std.testing.expectEqual(@as(u32, 7), key.ParentNodeId);
    try std.testing.expectEqual(@as(usize, 2), key.getIdentityLength());
    try std.testing.expectEqualSlices(u16, &[_]u16{ 'A', 0xe9 }, key.Identity[0..2]);
    try std.testing.expectEqualSlices(u16, &([_]u16{0} ** 254), key.Identity[2..]);
    const maximum = try records.createIndexKey(9, &([_]u8{'x'} ** 256));
    try std.testing.expectEqual(@as(u16, 520), maximum.KeyLength);
    try std.testing.expectEqual(@as(usize, 256), maximum.getIdentityLength());
    try std.testing.expectEqualSlices(u16, &([_]u16{'x'} ** 256), &maximum.Identity);
    try std.testing.expectEqual(@as(usize, 8), try records.indexKeySize(0));
    try std.testing.expectEqual(@as(usize, 12), try records.indexKeySize(2));
    try std.testing.expectEqual(@as(usize, 520), try records.indexKeySize(256));
}
