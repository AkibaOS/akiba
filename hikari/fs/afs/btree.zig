//! Hikari AFS B-Tree

const efi = @import("../../efi/efi.zig");
const constants = @import("constants.zig");
const types = @import("types.zig");

pub const BTreeError = error{
    read_failed,
    invalid_node,
    invalid_header,
    key_not_found,
    tree_empty,
    allocation_failed,
};

pub const BTree = struct {
    block_io: *efi.protocols.BlockIoProtocol,
    boot_services: *efi.services.BootServices,
    partition_start_lba: u64,
    cell_size: u32,
    base_span: types.SpanDescriptor,
    node_size: u32,
    root_node: u32,
    first_leaf: u32,
    last_leaf: u32,
    depth: u16,
    node_buffer: [*]u8,

    pub fn initialize(
        block_io: *efi.protocols.BlockIoProtocol,
        boot_services: *efi.services.BootServices,
        partition_start_lba: u64,
        cell_size: u32,
        base_span: types.SpanDescriptor,
        header: *const types.BTreeHeaderRecord,
    ) BTreeError!BTree {
        var node_buffer: [*]align(8) u8 = undefined;
        const alloc_status = boot_services.allocate_pool(
            .loader_data,
            header.node_size,
            &node_buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return BTreeError.allocation_failed;
        }

        return BTree{
            .block_io = block_io,
            .boot_services = boot_services,
            .partition_start_lba = partition_start_lba,
            .cell_size = cell_size,
            .base_span = base_span,
            .node_size = header.node_size,
            .root_node = header.root_node,
            .first_leaf = header.first_leaf_node,
            .last_leaf = header.last_leaf_node,
            .depth = header.depth,
            .node_buffer = node_buffer,
        };
    }

    pub fn read_node(self: *BTree, node_number: u32) BTreeError!*types.BTreeNodeDescriptor {
        const nodes_per_cell = self.cell_size / self.node_size;
        const cell_offset = node_number / nodes_per_cell;
        const node_offset_in_cell = (node_number % nodes_per_cell) * self.node_size;

        const cell_lba = self.partition_start_lba +
            ((self.base_span.start_cell + cell_offset) * self.cell_size / self.block_io.media.block_size);

        var cell_buffer: [*]align(8) u8 = undefined;
        const alloc_status = self.boot_services.allocate_pool(
            .loader_data,
            self.cell_size,
            &cell_buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return BTreeError.allocation_failed;
        }

        const read_status = self.block_io.read_blocks(
            self.block_io,
            self.block_io.media.media_id,
            cell_lba,
            self.cell_size,
            cell_buffer,
        );
        if (efi.types.is_error(read_status)) {
            return BTreeError.read_failed;
        }

        const node_ptr = cell_buffer + node_offset_in_cell;
        var i: u32 = 0;
        while (i < self.node_size) : (i += 1) {
            self.node_buffer[i] = node_ptr[i];
        }

        _ = self.boot_services.free_pool(cell_buffer);

        return @ptrCast(@alignCast(self.node_buffer));
    }

    pub fn get_record_offset(self: *BTree, record_index: u16) u16 {
        const offset_table_start = self.node_size - (@as(u32, record_index) + 1) * 2;
        const offset_ptr: *align(1) const u16 = @ptrCast(self.node_buffer + offset_table_start);
        return offset_ptr.*;
    }

    pub fn get_record_ptr(self: *BTree, record_index: u16) [*]u8 {
        const offset = self.get_record_offset(record_index);
        return self.node_buffer + offset;
    }

    pub fn search_index(
        self: *BTree,
        parent_node_id: u32,
        identity: []const u16,
    ) BTreeError!?*const types.UnitRecord {
        if (self.depth == 0) {
            return BTreeError.tree_empty;
        }

        var current_node = self.root_node;
        var current_depth: u16 = self.depth;

        while (current_depth > 0) {
            const node_desc = try self.read_node(current_node);

            if (node_desc.is_leaf()) {
                return self.search_leaf_for_unit(node_desc, parent_node_id, identity);
            }

            const next_node = self.search_index_node(node_desc, parent_node_id, identity);
            if (next_node) |node| {
                current_node = node;
                current_depth -= 1;
            } else {
                return null;
            }
        }

        return null;
    }

    fn search_index_node(
        self: *BTree,
        node_desc: *types.BTreeNodeDescriptor,
        parent_node_id: u32,
        identity: []const u16,
    ) ?u32 {
        var i: u16 = 0;
        while (i < node_desc.record_count) : (i += 1) {
            const record_ptr = self.get_record_ptr(i);
            const key: *const types.IndexKey = @ptrCast(@alignCast(record_ptr));

            const cmp = compare_keys(parent_node_id, identity, key);
            if (cmp <= 0) {
                const child_ptr: *align(1) const u32 = @ptrCast(record_ptr + key.key_length + 2);
                return child_ptr.*;
            }
        }

        if (node_desc.record_count > 0) {
            const last_record = self.get_record_ptr(node_desc.record_count - 1);
            const last_key: *const types.IndexKey = @ptrCast(@alignCast(last_record));
            const child_ptr: *align(1) const u32 = @ptrCast(last_record + last_key.key_length + 2);
            return child_ptr.*;
        }

        return null;
    }

    fn search_leaf_for_unit(
        self: *BTree,
        node_desc: *types.BTreeNodeDescriptor,
        parent_node_id: u32,
        identity: []const u16,
    ) ?*const types.UnitRecord {
        var i: u16 = 0;
        while (i < node_desc.record_count) : (i += 1) {
            const record_ptr = self.get_record_ptr(i);
            const key: *const types.IndexKey = @ptrCast(@alignCast(record_ptr));

            const cmp = compare_keys(parent_node_id, identity, key);
            if (cmp == 0) {
                const record_start = record_ptr + key.key_length + 2;
                const record_type_ptr: *align(1) const u16 = @ptrCast(record_start);
                const record_type = record_type_ptr.*;

                if (record_type == constants.index_record_type_unit) {
                    return @ptrCast(@alignCast(record_start));
                }
            }
        }

        return null;
    }

    pub fn search_index_for_stack(
        self: *BTree,
        parent_node_id: u32,
        identity: []const u16,
    ) BTreeError!?*const types.StackRecord {
        if (self.depth == 0) {
            return BTreeError.tree_empty;
        }

        var current_node = self.root_node;
        var current_depth: u16 = self.depth;

        while (current_depth > 0) {
            const node_desc = try self.read_node(current_node);

            if (node_desc.is_leaf()) {
                return self.search_leaf_for_stack(node_desc, parent_node_id, identity);
            }

            const next_node = self.search_index_node(node_desc, parent_node_id, identity);
            if (next_node) |node| {
                current_node = node;
                current_depth -= 1;
            } else {
                return null;
            }
        }

        return null;
    }

    fn search_leaf_for_stack(
        self: *BTree,
        node_desc: *types.BTreeNodeDescriptor,
        parent_node_id: u32,
        identity: []const u16,
    ) ?*const types.StackRecord {
        var i: u16 = 0;
        while (i < node_desc.record_count) : (i += 1) {
            const record_ptr = self.get_record_ptr(i);
            const key: *const types.IndexKey = @ptrCast(@alignCast(record_ptr));

            const cmp = compare_keys(parent_node_id, identity, key);
            if (cmp == 0) {
                const record_start = record_ptr + key.key_length + 2;
                const record_type_ptr: *align(1) const u16 = @ptrCast(record_start);
                const record_type = record_type_ptr.*;

                if (record_type == constants.index_record_type_stack) {
                    return @ptrCast(@alignCast(record_start));
                }
            }
        }

        return null;
    }

    pub fn get_thread_record(
        self: *BTree,
        node_id: u32,
    ) BTreeError!?*const types.ThreadRecord {
        var empty_identity: [0]u16 = undefined;
        return self.search_thread(node_id, &empty_identity);
    }

    fn search_thread(
        self: *BTree,
        node_id: u32,
        identity: []const u16,
    ) BTreeError!?*const types.ThreadRecord {
        if (self.depth == 0) {
            return BTreeError.tree_empty;
        }

        var current_node = self.root_node;
        var current_depth: u16 = self.depth;

        while (current_depth > 0) {
            const node_desc = try self.read_node(current_node);

            if (node_desc.is_leaf()) {
                return self.search_leaf_for_thread(node_desc, node_id, identity);
            }

            const next_node = self.search_index_node(node_desc, node_id, identity);
            if (next_node) |node| {
                current_node = node;
                current_depth -= 1;
            } else {
                return null;
            }
        }

        return null;
    }

    fn search_leaf_for_thread(
        self: *BTree,
        node_desc: *types.BTreeNodeDescriptor,
        node_id: u32,
        identity: []const u16,
    ) ?*const types.ThreadRecord {
        var i: u16 = 0;
        while (i < node_desc.record_count) : (i += 1) {
            const record_ptr = self.get_record_ptr(i);
            const key: *const types.IndexKey = @ptrCast(@alignCast(record_ptr));

            const cmp = compare_keys(node_id, identity, key);
            if (cmp == 0) {
                const record_start = record_ptr + key.key_length + 2;
                const record_type_ptr: *align(1) const u16 = @ptrCast(record_start);
                const record_type = record_type_ptr.*;

                if (record_type == constants.index_record_type_stack_thread or
                    record_type == constants.index_record_type_unit_thread)
                {
                    return @ptrCast(@alignCast(record_start));
                }
            }
        }

        return null;
    }
};

fn compare_keys(parent_node_id: u32, identity: []const u16, key: *const types.IndexKey) i32 {
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
