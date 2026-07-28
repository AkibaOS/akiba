//! GDT Entry Type

const constants = @import("mirai").boot.constants;

const access = constants.gdt.access;

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

    pub fn getBase(self: Entry) u32 {
        return @as(u32, self.BaseHigh) << 24 |
            @as(u32, self.BaseMiddle) << @bitSizeOf(u16) |
            @as(u32, self.BaseLow);
    }

    pub fn getLimit(self: Entry) u20 {
        return @as(u20, @truncate(self.LimitHighAndFlags & 0x0F)) << @bitSizeOf(u16) |
            @as(u20, self.LimitLow);
    }

    pub fn getFlags(self: Entry) u4 {
        return @truncate(self.LimitHighAndFlags >> 4);
    }

    pub fn isPresent(self: Entry) bool {
        return (self.Access & access.PRESENT) != 0;
    }

    pub fn getDPL(self: Entry) u2 {
        return @truncate((self.Access >> access.DPL_SHIFT) & access.DPL_MASK);
    }
};
