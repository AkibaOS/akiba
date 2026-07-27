//! TSS Descriptor Type (16 bytes in Long Mode)

const entry = @import("entry.zig");

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

    pub fn getBase(self: TSSDescriptor) u64 {
        return @as(u64, self.BaseHigh) << @bitSizeOf(u32) |
            @as(u64, self.BaseMiddleHigh) << 24 |
            @as(u64, self.BaseMiddleLow) << @bitSizeOf(u16) |
            @as(u64, self.BaseLow);
    }

    pub fn getLimit(self: TSSDescriptor) u20 {
        return @as(u20, @truncate(self.LimitHighAndFlags & 0x0F)) << @bitSizeOf(u16) |
            @as(u20, self.LimitLow);
    }

    pub fn asEntries(self: *TSSDescriptor) *[2]entry.Entry {
        return @ptrCast(self);
    }
};
