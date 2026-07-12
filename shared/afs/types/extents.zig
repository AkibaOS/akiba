//! AFS Extent Types

pub const SpanKey = extern struct {
    KeyLength: u16 = 0,
    ChannelType: u8 = 0,
    Padding: u8 = 0,
    NodeId: u32 = 0,
    StartCell: u32 = 0,
};

pub const SpanRecord = extern struct {
    StartCell: u64 = 0,
    CellCount: u64 = 0,
};
