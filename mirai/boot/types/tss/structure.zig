//! TSS Structure Type

pub const Tss = extern struct {
    reserved_0: u32 = 0,
    rsp0: u64 align(4) = 0,
    rsp1: u64 align(4) = 0,
    rsp2: u64 align(4) = 0,
    reserved_1: u64 align(4) = 0,
    ist1: u64 align(4) = 0,
    ist2: u64 align(4) = 0,
    ist3: u64 align(4) = 0,
    ist4: u64 align(4) = 0,
    ist5: u64 align(4) = 0,
    ist6: u64 align(4) = 0,
    ist7: u64 align(4) = 0,
    reserved_2: u64 align(4) = 0,
    reserved_3: u16 = 0,
    iopb_offset: u16 = @sizeOf(Tss),

    pub fn set_rsp0(self: *Tss, stack_top: u64) void {
        self.rsp0 = stack_top;
    }

    pub fn set_rsp1(self: *Tss, stack_top: u64) void {
        self.rsp1 = stack_top;
    }

    pub fn set_rsp2(self: *Tss, stack_top: u64) void {
        self.rsp2 = stack_top;
    }

    pub fn set_ist(self: *Tss, index: u8, stack_top: u64) void {
        switch (index) {
            1 => self.ist1 = stack_top,
            2 => self.ist2 = stack_top,
            3 => self.ist3 = stack_top,
            4 => self.ist4 = stack_top,
            5 => self.ist5 = stack_top,
            6 => self.ist6 = stack_top,
            7 => self.ist7 = stack_top,
            else => {},
        }
    }

    pub fn get_ist(self: *const Tss, index: u8) u64 {
        return switch (index) {
            1 => self.ist1,
            2 => self.ist2,
            3 => self.ist3,
            4 => self.ist4,
            5 => self.ist5,
            6 => self.ist6,
            7 => self.ist7,
            else => 0,
        };
    }

    pub fn get_address(self: *const Tss) u64 {
        return @intFromPtr(self);
    }

    pub fn clear(self: *Tss) void {
        self.* = Tss{};
    }
};

comptime {
    if (@sizeOf(Tss) != 104) {
        @compileError("TSS size must be 104 bytes");
    }
}
