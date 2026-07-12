//! AFS B-tree Search Operations

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");
const node_ops = @import("node.zig");

const IndexKey = types.IndexKey;
const BTreeNodeDescriptor = types.BTreeNodeDescriptor;
const StackRecord = types.StackRecord;
const UnitRecord = types.UnitRecord;
const ThreadRecord = types.ThreadRecord;

pub fn compare_keys(parent_node_id: u32, identity: []const u16, key: *align(1) const IndexKey) i32 {
    if (parent_node_id < key.parent_node_id) {
        return -1;
    }
    if (parent_node_id > key.parent_node_id) {
        return 1;
    }

    const key_identity_len = key.get_identity_length();
    const min_len = if (identity.len < key_identity_len) identity.len else key_identity_len;

    var i: usize = 0;
    while (i < min_len) : (i += 1) {
        const a = identity[i];
        const b = key.identity[i];
        if (a < b) {
            return -1;
        }
        if (a > b) {
            return 1;
        }
    }

    if (identity.len < key_identity_len) {
        return -1;
    }
    if (identity.len > key_identity_len) {
        return 1;
    }

    return 0;
}

pub fn search_index_node(
    node_buffer: [*]const u8,
    node_size: u32,
    record_count: u16,
    parent_node_id: u32,
    identity: []const u16,
) ?u32 {
    var i: u16 = 0;
    while (i < record_count) : (i += 1) {
        const record_ptr = node_ops.get_record_ptr_const(node_buffer, node_size, i);
        const key: *align(1) const IndexKey = @ptrCast(record_ptr);

        const cmp = compare_keys(parent_node_id, identity, key);
        if (cmp <= 0) {
            const child_ptr: *align(1) const u32 = @ptrCast(record_ptr + key.key_length);
            return child_ptr.*;
        }
    }

    if (record_count > 0) {
        const last_record = node_ops.get_record_ptr_const(node_buffer, node_size, record_count - 1);
        const last_key: *align(1) const IndexKey = @ptrCast(last_record);
        const child_ptr: *align(1) const u32 = @ptrCast(last_record + last_key.key_length);
        return child_ptr.*;
    }

    return null;
}

pub fn search_leaf_for_unit(
    node_buffer: [*]const u8,
    node_size: u32,
    record_count: u16,
    parent_node_id: u32,
    identity: []const u16,
) ?*align(1) const UnitRecord {
    var i: u16 = 0;
    while (i < record_count) : (i += 1) {
        const record_ptr = node_ops.get_record_ptr_const(node_buffer, node_size, i);
        const key: *align(1) const IndexKey = @ptrCast(record_ptr);

        const cmp = compare_keys(parent_node_id, identity, key);
        if (cmp == 0) {
            const record_start = record_ptr + key.key_length;
            const record_type_ptr: *align(1) const u16 = @ptrCast(record_start);
            const record_type = record_type_ptr.*;

            if (record_type == constants.records.index_unit) {
                return @ptrCast(record_start);
            }
        }
    }

    return null;
}

pub fn search_leaf_for_stack(
    node_buffer: [*]const u8,
    node_size: u32,
    record_count: u16,
    parent_node_id: u32,
    identity: []const u16,
) ?*align(1) const StackRecord {
    var i: u16 = 0;
    while (i < record_count) : (i += 1) {
        const record_ptr = node_ops.get_record_ptr_const(node_buffer, node_size, i);
        const key: *align(1) const IndexKey = @ptrCast(record_ptr);

        const cmp = compare_keys(parent_node_id, identity, key);
        if (cmp == 0) {
            const record_start = record_ptr + key.key_length;
            const record_type_ptr: *align(1) const u16 = @ptrCast(record_start);
            const record_type = record_type_ptr.*;

            if (record_type == constants.records.index_stack) {
                return @ptrCast(record_start);
            }
        }
    }

    return null;
}

pub fn search_leaf_for_thread(
    node_buffer: [*]const u8,
    node_size: u32,
    record_count: u16,
    node_id: u32,
    identity: []const u16,
) ?*align(1) const ThreadRecord {
    var i: u16 = 0;
    while (i < record_count) : (i += 1) {
        const record_ptr = node_ops.get_record_ptr_const(node_buffer, node_size, i);
        const key: *align(1) const IndexKey = @ptrCast(record_ptr);

        const cmp = compare_keys(node_id, identity, key);
        if (cmp == 0) {
            const record_start = record_ptr + key.key_length;
            const record_type_ptr: *align(1) const u16 = @ptrCast(record_start);
            const record_type = record_type_ptr.*;

            if (record_type == constants.records.index_stack_thread or
                record_type == constants.records.index_unit_thread)
            {
                return @ptrCast(record_start);
            }
        }
    }

    return null;
}
