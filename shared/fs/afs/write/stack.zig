//! AFS Stack Write Operations

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const StackRecord = types.StackRecord;
const UnitRecord = types.UnitRecord;
const ThreadRecord = types.ThreadRecord;
const IndexKey = types.IndexKey;
const Permissions = types.Permissions;
const ChannelInfo = types.ChannelInfo;

/// Create a stack record
pub fn create_stack_record(
    node_id: u32,
    timestamp: u64,
    mode: u16,
) StackRecord {
    return StackRecord{
        .record_type = constants.records.index_stack,
        .flags = constants.flags.unit_has_thread,
        .valence = 0,
        .node_id = node_id,
        .creation_timestamp = timestamp,
        .modification_timestamp = timestamp,
        .attribute_modification_timestamp = timestamp,
        .access_timestamp = timestamp,
        .backup_timestamp = 0,
        .permissions = Permissions{
            .owner_id = 0,
            .group_id = 0,
            .admin_flags = 0,
            .owner_flags = 0,
            .mode = mode,
            .special = .{ .inode_number = 0 },
        },
        .special = .{ .raw = [_]u8{0} ** 16 },
        .text_encoding = 0,
        .reserved = 0,
    };
}

/// Create a unit record
pub fn create_unit_record(
    node_id: u32,
    timestamp: u64,
    mode: u16,
    data_channel: ChannelInfo,
) UnitRecord {
    return UnitRecord{
        .record_type = constants.records.index_unit,
        .flags = constants.flags.unit_has_thread,
        .reserved1 = 0,
        .node_id = node_id,
        .creation_timestamp = timestamp,
        .modification_timestamp = timestamp,
        .attribute_modification_timestamp = timestamp,
        .access_timestamp = timestamp,
        .backup_timestamp = 0,
        .permissions = Permissions{
            .owner_id = 0,
            .group_id = 0,
            .admin_flags = 0,
            .owner_flags = 0,
            .mode = mode,
            .special = .{ .inode_number = 0 },
        },
        .special = .{ .raw = [_]u8{0} ** 16 },
        .text_encoding = 0,
        .reserved2 = 0,
        .data_channel = data_channel,
        .resource_channel = ChannelInfo{},
    };
}

/// Create an index key for a catalog entry
pub fn create_index_key(
    parent_node_id: u32,
    identity: []const u8,
) IndexKey {
    var key = IndexKey{
        .key_length = @intCast(8 + identity.len * 2),
        .parent_node_id = parent_node_id,
        .identity = [_]u16{0} ** 256,
    };

    for (identity, 0..) |char, i| {
        key.identity[i] = char;
    }

    return key;
}

/// Get the size of an index key in bytes
pub fn index_key_size(identity_len: usize) usize {
    return 8 + identity_len * 2;
}
