//! Hikari AFS B-Tree

const efi = @import("../../efi/efi.zig");
const shared_afs = @import("shared").afs;
const block_io = @import("block.zig");

const EfiBlockContext = block_io.EfiBlockContext;

const BTreeNodeDescriptor = shared_afs.BTreeNodeDescriptor;
const BTreeHeaderRecord = shared_afs.BTreeHeaderRecord;
const IndexKey = shared_afs.types.IndexKey;
const StackRecord = shared_afs.StackRecord;
const UnitRecord = shared_afs.UnitRecord;
const ThreadRecord = shared_afs.types.ThreadRecord;
const SpanDescriptor = shared_afs.SpanDescriptor;

const btree_ops = shared_afs.btree;
const constants = shared_afs.constants;

pub const BTreeError = error{
    ReadFailed,
    InvalidNode,
    InvalidHeader,
    KeyNotFound,
    TreeEmpty,
    AllocationFailed,
};

pub const BTree = struct {
    block_io: *efi.protocols.BlockIoProtocol,
    boot_services: *efi.services.BootServices,
    partition_start_lba: u64,
    cell_size: u32,
    base_span: SpanDescriptor,
    node_size: u32,
    root_node: u32,
    first_leaf: u32,
    last_leaf: u32,
    depth: u16,
    node_buffer: [*]u8,

    pub fn initialize(
        block_io_proto: *efi.protocols.BlockIoProtocol,
        boot_services: *efi.services.BootServices,
        partition_start_lba: u64,
        cell_size: u32,
        base_span: SpanDescriptor,
        header: *const BTreeHeaderRecord,
    ) BTreeError!BTree {
        var node_buffer: [*]align(8) u8 = undefined;
        const alloc_status = boot_services.allocate_pool(
            .loader_data,
            header.node_size,
            &node_buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return BTreeError.AllocationFailed;
        }

        return BTree{
            .block_io = block_io_proto,
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

    pub fn read_node(self: *BTree, node_number: u32) BTreeError!*BTreeNodeDescriptor {
        const cell_offset = btree_ops.get_node_cell(node_number, self.cell_size, self.node_size);
        const node_offset_in_cell = btree_ops.get_node_offset_in_cell(node_number, self.cell_size, self.node_size);

        const cell_lba = self.partition_start_lba +
            ((self.base_span.start_cell + cell_offset) * self.cell_size / self.block_io.media.block_size);

        var cell_buffer: [*]align(8) u8 = undefined;
        const alloc_status = self.boot_services.allocate_pool(
            .loader_data,
            self.cell_size,
            &cell_buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return BTreeError.AllocationFailed;
        }

        const read_status = self.block_io.read_blocks(
            self.block_io,
            self.block_io.media.media_id,
            cell_lba,
            self.cell_size,
            cell_buffer,
        );
        if (efi.types.is_error(read_status)) {
            return BTreeError.ReadFailed;
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
        return btree_ops.get_record_offset(self.node_buffer, self.node_size, record_index);
    }

    pub fn get_record_ptr(self: *BTree, record_index: u16) [*]u8 {
        return btree_ops.get_record_ptr(self.node_buffer, self.node_size, record_index);
    }

    pub fn search_index(
        self: *BTree,
        parent_node_id: u32,
        identity: []const u16,
    ) BTreeError!?*align(1) const UnitRecord {
        if (self.depth == 0) {
            return BTreeError.TreeEmpty;
        }

        var current_node = self.root_node;
        var current_depth: u16 = self.depth;

        while (current_depth > 0) {
            const node_desc = try self.read_node(current_node);

            if (node_desc.is_leaf()) {
                return btree_ops.search_leaf_for_unit(
                    self.node_buffer,
                    self.node_size,
                    node_desc.record_count,
                    parent_node_id,
                    identity,
                );
            }

            const next_node = btree_ops.search_index_node(
                self.node_buffer,
                self.node_size,
                node_desc.record_count,
                parent_node_id,
                identity,
            );
            if (next_node) |node| {
                current_node = node;
                current_depth -= 1;
            } else {
                return null;
            }
        }

        return null;
    }

    pub fn search_index_for_stack(
        self: *BTree,
        parent_node_id: u32,
        identity: []const u16,
    ) BTreeError!?*align(1) const StackRecord {
        if (self.depth == 0) {
            return BTreeError.TreeEmpty;
        }

        var current_node = self.root_node;
        var current_depth: u16 = self.depth;

        while (current_depth > 0) {
            const node_desc = try self.read_node(current_node);

            if (node_desc.is_leaf()) {
                return btree_ops.search_leaf_for_stack(
                    self.node_buffer,
                    self.node_size,
                    node_desc.record_count,
                    parent_node_id,
                    identity,
                );
            }

            const next_node = btree_ops.search_index_node(
                self.node_buffer,
                self.node_size,
                node_desc.record_count,
                parent_node_id,
                identity,
            );
            if (next_node) |node| {
                current_node = node;
                current_depth -= 1;
            } else {
                return null;
            }
        }

        return null;
    }

    pub fn get_thread_record(
        self: *BTree,
        node_id: u32,
    ) BTreeError!?*align(1) const ThreadRecord {
        var empty_identity: [0]u16 = undefined;
        return self.search_thread(node_id, &empty_identity);
    }

    fn search_thread(
        self: *BTree,
        node_id: u32,
        identity: []const u16,
    ) BTreeError!?*align(1) const ThreadRecord {
        if (self.depth == 0) {
            return BTreeError.TreeEmpty;
        }

        var current_node = self.root_node;
        var current_depth: u16 = self.depth;

        while (current_depth > 0) {
            const node_desc = try self.read_node(current_node);

            if (node_desc.is_leaf()) {
                return btree_ops.search_leaf_for_thread(
                    self.node_buffer,
                    self.node_size,
                    node_desc.record_count,
                    node_id,
                    identity,
                );
            }

            const next_node = btree_ops.search_index_node(
                self.node_buffer,
                self.node_size,
                node_desc.record_count,
                node_id,
                identity,
            );
            if (next_node) |node| {
                current_node = node;
                current_depth -= 1;
            } else {
                return null;
            }
        }

        return null;
    }
};
