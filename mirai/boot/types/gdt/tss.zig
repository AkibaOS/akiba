//! TSS Descriptor Type

pub const TSSDescriptor = packed struct {
    LimitLow: u16,
    BaseLow: u16,
    BaseMiddleLow: u8,
    Access: u8,
    LimitHighAndFlags: u8,
    BaseMiddleHigh: u8,
    BaseHigh: u32,
    Reserved: u32,

    pub fn init(base: u64, limit: u20, access_byte: u8) TSSDescriptor {
        return TSSDescriptor{
            .LimitLow = @truncate(limit),
            .BaseLow = @truncate(base),
            .BaseMiddleLow = @truncate(base >> @bitSizeOf(u16)),
            .Access = access_byte,
            .LimitHighAndFlags = @truncate(limit >> @bitSizeOf(u16)),
            .BaseMiddleHigh = @truncate(base >> 24),
            .BaseHigh = @truncate(base >> @bitSizeOf(u32)),
            .Reserved = 0,
        };
    }
};
