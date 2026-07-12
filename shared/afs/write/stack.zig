//! AFS Stack Write Operations

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const ChannelInfo = types.volume.ChannelInfo;
const IndexKey = types.btree.IndexKey;
const Permissions = types.catalog.Permissions;
const StackRecord = types.catalog.StackRecord;
const UnitRecord = types.catalog.UnitRecord;

pub fn createStackRecord(
    node_id: u32,
    timestamp: u64,
    mode: u16,
) StackRecord {
    return StackRecord{
        .RecordType = constants.records.INDEX_STACK,
        .Flags = constants.flags.UNIT_HAS_THREAD,
        .Valence = 0,
        .NodeId = node_id,
        .CreationTimestamp = timestamp,
        .ModificationTimestamp = timestamp,
        .AttributeModificationTimestamp = timestamp,
        .AccessTimestamp = timestamp,
        .BackupTimestamp = 0,
        .Permissions = Permissions{
            .OwnerId = 0,
            .GroupId = 0,
            .AdminFlags = 0,
            .OwnerFlags = 0,
            .Mode = mode,
            .Special = .{ .InodeNumber = 0 },
        },
        .Special = .{ .Raw = [_]u8{0} ** 16 },
        .TextEncoding = 0,
        .Reserved = 0,
    };
}

pub fn createUnitRecord(
    node_id: u32,
    timestamp: u64,
    mode: u16,
    data_channel: ChannelInfo,
) UnitRecord {
    return UnitRecord{
        .RecordType = constants.records.INDEX_UNIT,
        .Flags = constants.flags.UNIT_HAS_THREAD,
        .Reserved1 = 0,
        .NodeId = node_id,
        .CreationTimestamp = timestamp,
        .ModificationTimestamp = timestamp,
        .AttributeModificationTimestamp = timestamp,
        .AccessTimestamp = timestamp,
        .BackupTimestamp = 0,
        .Permissions = Permissions{
            .OwnerId = 0,
            .GroupId = 0,
            .AdminFlags = 0,
            .OwnerFlags = 0,
            .Mode = mode,
            .Special = .{ .InodeNumber = 0 },
        },
        .Special = .{ .Raw = [_]u8{0} ** 16 },
        .TextEncoding = 0,
        .Reserved2 = 0,
        .DataChannel = data_channel,
        .ResourceChannel = ChannelInfo{},
    };
}

pub fn createIndexKey(
    parent_node_id: u32,
    identity: []const u8,
) IndexKey {
    var key = IndexKey{
        .KeyLength = @intCast(@as(usize, constants.btree.INDEX_KEY_HEADER_SIZE) + identity.len * @sizeOf(u16)),
        .ParentNodeId = parent_node_id,
        .Identity = [_]u16{0} ** 256,
    };

    for (identity, 0..) |char, index| {
        key.Identity[index] = char;
    }

    return key;
}

pub fn indexKeySize(identity_length: usize) usize {
    return @as(usize, constants.btree.INDEX_KEY_HEADER_SIZE) + identity_length * @sizeOf(u16);
}
