//! TSS Structure Type

const constants = @import("mirai").boot.constants;

const limits = constants.tss.limits;

pub const TSS = extern struct {
    Reserved0: u32 = 0,
    RSP0: u64 align(4) = 0,
    RSP1: u64 align(4) = 0,
    RSP2: u64 align(4) = 0,
    Reserved1: u64 align(4) = 0,
    IST1: u64 align(4) = 0,
    IST2: u64 align(4) = 0,
    IST3: u64 align(4) = 0,
    IST4: u64 align(4) = 0,
    IST5: u64 align(4) = 0,
    IST6: u64 align(4) = 0,
    IST7: u64 align(4) = 0,
    Reserved2: u64 align(4) = 0,
    Reserved3: u16 = 0,
    IOPBOffset: u16 = @sizeOf(TSS),

    pub fn setRSP0(self: *TSS, stack_top: u64) void {
        self.RSP0 = stack_top;
    }

    pub fn setRSP1(self: *TSS, stack_top: u64) void {
        self.RSP1 = stack_top;
    }

    pub fn setRSP2(self: *TSS, stack_top: u64) void {
        self.RSP2 = stack_top;
    }

    pub fn setIST(self: *TSS, index: u8, stack_top: u64) void {
        switch (index) {
            1 => self.IST1 = stack_top,
            2 => self.IST2 = stack_top,
            3 => self.IST3 = stack_top,
            4 => self.IST4 = stack_top,
            5 => self.IST5 = stack_top,
            6 => self.IST6 = stack_top,
            7 => self.IST7 = stack_top,
            else => {},
        }
    }

    pub fn getIST(self: *const TSS, index: u8) u64 {
        return switch (index) {
            1 => self.IST1,
            2 => self.IST2,
            3 => self.IST3,
            4 => self.IST4,
            5 => self.IST5,
            6 => self.IST6,
            7 => self.IST7,
            else => 0,
        };
    }

    pub fn getAddress(self: *const TSS) u64 {
        return @intFromPtr(self);
    }

    pub fn clear(self: *TSS) void {
        self.* = TSS{};
    }
};

comptime {
    if (@sizeOf(TSS) != limits.TSS_SIZE) {
        @compileError("TSS size must be 104 bytes");
    }
}
