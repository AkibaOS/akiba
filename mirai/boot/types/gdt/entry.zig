//! GDT Entry Type

pub const Entry = packed struct {
    LimitLow: u16,
    BaseLow: u16,
    BaseMiddle: u8,
    Access: u8,
    LimitHighAndFlags: u8,
    BaseHigh: u8,

    pub fn init(base: u32, limit: u20, access_byte: u8, flags_nibble: u4) Entry {
        return Entry{
            .LimitLow = @truncate(limit),
            .BaseLow = @truncate(base),
            .BaseMiddle = @truncate(base >> @bitSizeOf(u16)),
            .Access = access_byte,
            .LimitHighAndFlags = @as(u8, flags_nibble) << 4 | @as(u8, @truncate(limit >> @bitSizeOf(u16))),
            .BaseHigh = @truncate(base >> 24),
        };
    }

    pub fn nullEntry() Entry {
        return Entry{
            .LimitLow = 0,
            .BaseLow = 0,
            .BaseMiddle = 0,
            .Access = 0,
            .LimitHighAndFlags = 0,
            .BaseHigh = 0,
        };
    }
};
