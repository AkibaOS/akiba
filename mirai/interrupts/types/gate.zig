//! IDT Gate Descriptor (64-bit)

pub const GateType = enum(u4) {
    interrupt = 0xE,
    trap = 0xF,
};

pub const DPL = enum(u2) {
    ring0 = 0,
    ring1 = 1,
    ring2 = 2,
    ring3 = 3,
};

pub const Gate64 = packed struct(u128) {
    offset_low: u16,
    selector: u16,
    ist: u3,
    reserved0: u5 = 0,
    gate_type: GateType,
    zero: u1 = 0,
    dpl: DPL,
    present: bool,
    offset_mid: u16,
    offset_high: u32,
    reserved1: u32 = 0,

    pub fn empty() Gate64 {
        return @bitCast(@as(u128, 0));
    }

    pub fn interrupt(handler: u64, selector: u16, ist: u3, dpl: DPL) Gate64 {
        return Gate64{
            .offset_low = @truncate(handler),
            .selector = selector,
            .ist = ist,
            .gate_type = .interrupt,
            .dpl = dpl,
            .present = true,
            .offset_mid = @truncate(handler >> 16),
            .offset_high = @truncate(handler >> 32),
        };
    }

    pub fn trap(handler: u64, selector: u16, ist: u3, dpl: DPL) Gate64 {
        return Gate64{
            .offset_low = @truncate(handler),
            .selector = selector,
            .ist = ist,
            .gate_type = .trap,
            .dpl = dpl,
            .present = true,
            .offset_mid = @truncate(handler >> 16),
            .offset_high = @truncate(handler >> 32),
        };
    }

    pub fn get_offset(self: Gate64) u64 {
        return @as(u64, self.offset_low) |
            (@as(u64, self.offset_mid) << 16) |
            (@as(u64, self.offset_high) << 32);
    }
};

comptime {
    if (@sizeOf(Gate64) != 16) @compileError("Gate64 must be 16 bytes");
}
