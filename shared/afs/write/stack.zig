//! AFS Stack Write Operations

const constants = @import("shared").afs.constants;
const errors = @import("shared").afs.errors;
const separators = @import("utils").path.constants.separators;
const types = @import("shared").afs.types;

const ChannelInfo = types.volume.ChannelInfo;
const IndexKey = types.btree.IndexKey;
const Permissions = types.catalog.Permissions;
const StackRecord = types.catalog.StackRecord;
const UnitRecord = types.catalog.UnitRecord;
const WriteError = errors.write.WriteError;

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
) WriteError!IndexKey {
    const key_size = try indexKeySize(identity.len);
    var key = IndexKey{
        .KeyLength = @intCast(key_size),
        .ParentNodeId = parent_node_id,
        .Identity = [_]u16{0} ** 256,
    };

    for (identity, 0..) |character, index| {
        if (character == 0 or character == separators.FORWARD_SLASH or character == separators.BACK_SLASH) return WriteError.InvalidIdentity;
        key.Identity[index] = character;
    }

    return key;
}

pub fn indexKeySize(identity_length: usize) WriteError!usize {
    if (identity_length > @as(IndexKey, undefined).Identity.len) return WriteError.InvalidIdentity;
    return @as(usize, constants.btree.INDEX_KEY_HEADER_SIZE) + identity_length * @sizeOf(u16);
}
