//! IDT Gate Descriptor (64-bit)

pub const GateType = enum(u4) {
    Interrupt = 0xE,
    Trap = 0xF,
};

pub const DPL = enum(u2) {
    Ring0 = 0,
    Ring1 = 1,
    Ring2 = 2,
    Ring3 = 3,
};

pub const Gate64 = packed struct(u128) {
    OffsetLow: u16,
    Selector: u16,
    IST: u3,
    Reserved0: u5 = 0,
    GateType: GateType,
    Zero: u1 = 0,
    DPL: DPL,
    Present: bool,
    OffsetMid: u16,
    OffsetHigh: u32,
    Reserved1: u32 = 0,

    pub fn empty() Gate64 {
        return @bitCast(@as(u128, 0));
    }

    pub fn interrupt(handler: u64, selector: u16, ist: u3, dpl: DPL) Gate64 {
        return Gate64{
            .OffsetLow = @truncate(handler),
            .Selector = selector,
            .IST = ist,
            .GateType = .Interrupt,
            .DPL = dpl,
            .Present = true,
            .OffsetMid = @truncate(handler >> @bitSizeOf(u16)),
            .OffsetHigh = @truncate(handler >> @bitSizeOf(u32)),
        };
    }

    pub fn trap(handler: u64, selector: u16, ist: u3, dpl: DPL) Gate64 {
        return Gate64{
            .OffsetLow = @truncate(handler),
            .Selector = selector,
            .IST = ist,
            .GateType = .Trap,
            .DPL = dpl,
            .Present = true,
            .OffsetMid = @truncate(handler >> @bitSizeOf(u16)),
            .OffsetHigh = @truncate(handler >> @bitSizeOf(u32)),
        };
    }

    pub fn getOffset(self: Gate64) u64 {
        return @as(u64, self.OffsetLow) |
            (@as(u64, self.OffsetMid) << @bitSizeOf(u16)) |
            (@as(u64, self.OffsetHigh) << @bitSizeOf(u32));
    }
};

comptime {
    if (@sizeOf(Gate64) != 16) @compileError("Gate64 must be 16 bytes");
}
