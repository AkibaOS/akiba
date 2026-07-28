//! Flavor State Structures

const strings = @import("mirai").crimson.strings;

const names = strings.names;

pub const Flavor = enum(u8) {
    None = 0,
    General = 1,
    Float = 2,
    Debug = 3,
    AVX = 4,
    Full = 5,

    pub fn includesGeneral(self: Flavor) bool {
        return self == .General or self == .Full;
    }

    pub fn includesFloat(self: Flavor) bool {
        return self == .Float or self == .Full;
    }

    pub fn includesDebug(self: Flavor) bool {
        return self == .Debug or self == .Full;
    }

    pub fn name(self: Flavor) []const u8 {
        return switch (self) {
            .None => names.FLAVOR_NONE,
            .General => names.FLAVOR_GENERAL,
            .Float => names.FLAVOR_FLOAT,
            .Debug => names.FLAVOR_DEBUG,
            .AVX => names.FLAVOR_AVX,
            .Full => names.FLAVOR_FULL,
        };
    }
};

pub const FloatState = extern struct {
    FCW: u16,
    FSW: u16,
    FTW: u8,
    Reserved1: u8,
    FOP: u16,
    FIP: u64,
    FDP: u64,
    MXCSR: u32,
    MXCSRMask: u32,
    ST: [8][16]u8,
    XMM: [16][16]u8,
    Reserved2: [96]u8,

    pub fn clear(self: *FloatState) void {
        const bytes: *[@sizeOf(FloatState)]u8 = @ptrCast(self);
        @memset(bytes, 0);
    }
};

pub const DebugState = extern struct {
    DR0: u64,
    DR1: u64,
    DR2: u64,
    DR3: u64,
    DR4: u64,
    DR5: u64,
    DR6: u64,
    DR7: u64,

    pub fn clear(self: *DebugState) void {
        self.* = DebugState{
            .DR0 = 0,
            .DR1 = 0,
            .DR2 = 0,
            .DR3 = 0,
            .DR4 = 0,
            .DR5 = 0,
            .DR6 = 0,
            .DR7 = 0,
        };
    }
};

pub const AvxState = extern struct {
    YMMHigh: [16][16]u8,
    ZMM: [32][64]u8,
    OpMask: [8]u64,

    pub fn clear(self: *AvxState) void {
        for (&self.YMMHigh) |*row| {
            @memset(row, 0);
        }
        for (&self.ZMM) |*row| {
            @memset(row, 0);
        }
        @memset(&self.OpMask, 0);
    }
};
