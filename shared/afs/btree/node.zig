//! AFS B-tree Node Operations

pub fn getNodeCell(node_number: u32, cell_size: u32, node_size: u32) u64 {
    const nodes_per_cell = cell_size / node_size;
    return node_number / nodes_per_cell;
}

pub fn getNodeOffsetInCell(node_number: u32, cell_size: u32, node_size: u32) u32 {
    const nodes_per_cell = cell_size / node_size;
    return (node_number % nodes_per_cell) * node_size;
}

pub fn getRecordOffset(node_buffer: [*]const u8, node_size: u32, record_index: u16) u16 {
    const offset_table_start = node_size - (@as(u32, record_index) + 1) * @sizeOf(u16);
    const offset_pointer: *align(1) const u16 = @ptrCast(node_buffer + offset_table_start);
    return offset_pointer.*;
}

pub fn getRecordPointer(node_buffer: [*]u8, node_size: u32, record_index: u16) [*]u8 {
    const offset = getRecordOffset(node_buffer, node_size, record_index);
    return node_buffer + offset;
}

pub fn getRecordPointerConst(node_buffer: [*]const u8, node_size: u32, record_index: u16) [*]const u8 {
    const offset = getRecordOffset(node_buffer, node_size, record_index);
    return node_buffer + offset;
}
