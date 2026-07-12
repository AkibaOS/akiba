//! AFS Extent Types

pub const SpanKey = extern struct {
    key_length: u16 = 0,
    channel_type: u8 = 0,
    padding: u8 = 0,
    node_id: u32 = 0,
    start_cell: u32 = 0,
};

pub const SpanRecord = extern struct {
    start_cell: u64 = 0,
    cell_count: u64 = 0,
};
