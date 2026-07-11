//! AFS B-tree Node Operations

const types = @import("../types/types.zig");
const io = @import("../io/io.zig");

const BlockReader = io.BlockReader;
const BlockError = io.BlockError;
const BTreeNodeDescriptor = types.BTreeNodeDescriptor;

pub const NodeError = error{
    ReadFailed,
    InvalidNode,
    OutOfBounds,
};

pub fn get_node_cell(node_number: u32, cell_size: u32, node_size: u32) u64 {
    const nodes_per_cell = cell_size / node_size;
    return node_number / nodes_per_cell;
}

pub fn get_node_offset_in_cell(node_number: u32, cell_size: u32, node_size: u32) u32 {
    const nodes_per_cell = cell_size / node_size;
    return (node_number % nodes_per_cell) * node_size;
}

pub fn get_record_offset(node_buffer: [*]const u8, node_size: u32, record_index: u16) u16 {
    const offset_table_start = node_size - (@as(u32, record_index) + 1) * 2;
    const offset_ptr: *align(1) const u16 = @ptrCast(node_buffer + offset_table_start);
    return offset_ptr.*;
}

pub fn get_record_ptr(node_buffer: [*]u8, node_size: u32, record_index: u16) [*]u8 {
    const offset = get_record_offset(node_buffer, node_size, record_index);
    return node_buffer + offset;
}

pub fn get_record_ptr_const(node_buffer: [*]const u8, node_size: u32, record_index: u16) [*]const u8 {
    const offset = get_record_offset(node_buffer, node_size, record_index);
    return node_buffer + offset;
}
