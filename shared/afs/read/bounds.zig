//! AFS Read Bounds

const types = @import("shared").afs.types;

pub fn spanFits(span: types.volume.SpanDescriptor, total_cells: u64) bool {
    return span.CellCount != 0 and span.StartCell < total_cells and
        span.CellCount <= total_cells - span.StartCell;
}

pub fn cellLBA(partition_start: u64, partition_end: u64, block_size: u32, cell_size: u32, cell: u64, read_size: u64) ?u64 {
    if (partition_start == 0 or partition_end < partition_start or block_size == 0 or
        cell_size == 0 or cell_size % block_size != 0 or read_size == 0 or read_size % block_size != 0)
    {
        return null;
    }
    const partition_blocks = partition_end - partition_start + 1;
    const blocks_per_cell = cell_size / block_size;
    if (cell > (partition_blocks - 1) / blocks_per_cell) return null;
    const offset = cell * blocks_per_cell;
    if (read_size / block_size > partition_blocks - offset) return null;
    return partition_start + offset;
}
