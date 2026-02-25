//! GDT Entry Type

pub const Entry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    limit_high_and_flags: u8,
    base_high: u8,

    pub fn init(base: u32, limit: u20, access_byte: u8, flags_nibble: u4) Entry {
        return Entry{
            .limit_low = @truncate(limit),
            .base_low = @truncate(base),
            .base_middle = @truncate(base >> 16),
            .access = access_byte,
            .limit_high_and_flags = @as(u8, flags_nibble) << 4 | @as(u8, @truncate(limit >> 16)),
            .base_high = @truncate(base >> 24),
        };
    }

    pub fn null_entry() Entry {
        return Entry{
            .limit_low = 0,
            .base_low = 0,
            .base_middle = 0,
            .access = 0,
            .limit_high_and_flags = 0,
            .base_high = 0,
        };
    }

    pub fn get_base(self: Entry) u32 {
        return @as(u32, self.base_high) << 24 |
            @as(u32, self.base_middle) << 16 |
            @as(u32, self.base_low);
    }

    pub fn get_limit(self: Entry) u20 {
        return @as(u20, @truncate(self.limit_high_and_flags & 0x0F)) << 16 |
            @as(u20, self.limit_low);
    }

    pub fn get_flags(self: Entry) u4 {
        return @truncate(self.limit_high_and_flags >> 4);
    }

    pub fn is_present(self: Entry) bool {
        return (self.access & 0x80) != 0;
    }

    pub fn get_dpl(self: Entry) u2 {
        return @truncate((self.access >> 5) & 0x03);
    }
};
