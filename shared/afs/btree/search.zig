//! AFS B-tree Search Operations

const constants = @import("../constants/constants.zig");
const node = @import("node.zig");
const types = @import("../types/types.zig");

const IndexKey = types.btree.IndexKey;
const StackRecord = types.catalog.StackRecord;
const ThreadRecord = types.catalog.ThreadRecord;
const UnitRecord = types.catalog.UnitRecord;

pub fn compareKeys(parent_node_id: u32, identity: []const u16, key: *align(1) const IndexKey) i32 {
    if (parent_node_id < key.ParentNodeId) {
        return -1;
    }
    if (parent_node_id > key.ParentNodeId) {
        return 1;
    }

    const key_identity_length = key.getIdentityLength();
    const min_length = if (identity.len < key_identity_length) identity.len else key_identity_length;

    var index: usize = 0;
    while (index < min_length) : (index += 1) {
        const left_char = identity[index];
        const right_char = key.Identity[index];
        if (left_char < right_char) {
            return -1;
        }
        if (left_char > right_char) {
            return 1;
        }
    }

    if (identity.len < key_identity_length) {
        return -1;
    }
    if (identity.len > key_identity_length) {
        return 1;
    }

    return 0;
}

pub fn searchIndexNode(
    node_buffer: [*]const u8,
    node_size: u32,
    record_count: u16,
    parent_node_id: u32,
    identity: []const u16,
) ?u32 {
    var index: u16 = 0;
    while (index < record_count) : (index += 1) {
        const record_pointer = node.getRecordPointerConst(node_buffer, node_size, index);
        const key: *align(1) const IndexKey = @ptrCast(record_pointer);

        const comparison = compareKeys(parent_node_id, identity, key);
        if (comparison <= 0) {
            const child_pointer: *align(1) const u32 = @ptrCast(record_pointer + key.KeyLength);
            return child_pointer.*;
        }
    }

    if (record_count > 0) {
        const last_record = node.getRecordPointerConst(node_buffer, node_size, record_count - 1);
        const last_key: *align(1) const IndexKey = @ptrCast(last_record);
        const child_pointer: *align(1) const u32 = @ptrCast(last_record + last_key.KeyLength);
        return child_pointer.*;
    }

    return null;
}

pub fn searchLeafForUnit(
    node_buffer: [*]const u8,
    node_size: u32,
    record_count: u16,
    parent_node_id: u32,
    identity: []const u16,
) ?*align(1) const UnitRecord {
    var index: u16 = 0;
    while (index < record_count) : (index += 1) {
        const record_pointer = node.getRecordPointerConst(node_buffer, node_size, index);
        const key: *align(1) const IndexKey = @ptrCast(record_pointer);

        const comparison = compareKeys(parent_node_id, identity, key);
        if (comparison == 0) {
            const record_start = record_pointer + key.KeyLength;
            const record_type_pointer: *align(1) const u16 = @ptrCast(record_start);
            const record_type = record_type_pointer.*;

            if (record_type == constants.records.INDEX_UNIT) {
                return @ptrCast(record_start);
            }
        }
    }

    return null;
}

pub fn searchLeafForStack(
    node_buffer: [*]const u8,
    node_size: u32,
    record_count: u16,
    parent_node_id: u32,
    identity: []const u16,
) ?*align(1) const StackRecord {
    var index: u16 = 0;
    while (index < record_count) : (index += 1) {
        const record_pointer = node.getRecordPointerConst(node_buffer, node_size, index);
        const key: *align(1) const IndexKey = @ptrCast(record_pointer);

        const comparison = compareKeys(parent_node_id, identity, key);
        if (comparison == 0) {
            const record_start = record_pointer + key.KeyLength;
            const record_type_pointer: *align(1) const u16 = @ptrCast(record_start);
            const record_type = record_type_pointer.*;

            if (record_type == constants.records.INDEX_STACK) {
                return @ptrCast(record_start);
            }
        }
    }

    return null;
}

pub fn searchLeafForThread(
    node_buffer: [*]const u8,
    node_size: u32,
    record_count: u16,
    node_id: u32,
    identity: []const u16,
) ?*align(1) const ThreadRecord {
    var index: u16 = 0;
    while (index < record_count) : (index += 1) {
        const record_pointer = node.getRecordPointerConst(node_buffer, node_size, index);
        const key: *align(1) const IndexKey = @ptrCast(record_pointer);

        const comparison = compareKeys(node_id, identity, key);
        if (comparison == 0) {
            const record_start = record_pointer + key.KeyLength;
            const record_type_pointer: *align(1) const u16 = @ptrCast(record_start);
            const record_type = record_type_pointer.*;

            if (record_type == constants.records.INDEX_STACK_THREAD or
                record_type == constants.records.INDEX_UNIT_THREAD)
            {
                return @ptrCast(record_start);
            }
        }
    }

    return null;
}
