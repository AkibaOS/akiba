//! TSS Descriptor Type (16 bytes in Long Mode)

const Entry = @import("entry.zig").Entry;

pub const TssDescriptor = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle_low: u8,
    access: u8,
    limit_high_and_flags: u8,
    base_middle_high: u8,
    base_high: u32,
    reserved: u32,

    pub fn init(base: u64, limit: u20, access_byte: u8) TssDescriptor {
        return TssDescriptor{
            .limit_low = @truncate(limit),
            .base_low = @truncate(base),
            .base_middle_low = @truncate(base >> 16),
            .access = access_byte,
            .limit_high_and_flags = @truncate(limit >> 16),
            .base_middle_high = @truncate(base >> 24),
            .base_high = @truncate(base >> 32),
            .reserved = 0,
        };
    }

    pub fn get_base(self: TssDescriptor) u64 {
        return @as(u64, self.base_high) << 32 |
            @as(u64, self.base_middle_high) << 24 |
            @as(u64, self.base_middle_low) << 16 |
            @as(u64, self.base_low);
    }

    pub fn get_limit(self: TssDescriptor) u20 {
        return @as(u20, @truncate(self.limit_high_and_flags & 0x0F)) << 16 |
            @as(u20, self.limit_low);
    }

    pub fn as_entries(self: *TssDescriptor) *[2]Entry {
        return @ptrCast(self);
    }
};
