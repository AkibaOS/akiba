//! Flavor State Structures

pub const FloatState = extern struct {
    fcw: u16,
    fsw: u16,
    ftw: u8,
    reserved1: u8,
    fop: u16,
    fip: u64,
    fdp: u64,
    mxcsr: u32,
    mxcsr_mask: u32,
    st: [8][16]u8,
    xmm: [16][16]u8,
    reserved2: [96]u8,

    pub fn clear(self: *FloatState) void {
        const bytes: *[512]u8 = @ptrCast(self);
        for (bytes) |*b| {
            b.* = 0;
        }
    }
};

pub const DebugState = extern struct {
    dr0: u64,
    dr1: u64,
    dr2: u64,
    dr3: u64,
    dr4: u64,
    dr5: u64,
    dr6: u64,
    dr7: u64,

    pub fn clear(self: *DebugState) void {
        self.* = DebugState{
            .dr0 = 0,
            .dr1 = 0,
            .dr2 = 0,
            .dr3 = 0,
            .dr4 = 0,
            .dr5 = 0,
            .dr6 = 0,
            .dr7 = 0,
        };
    }
};

pub const AvxState = extern struct {
    ymm_high: [16][16]u8,
    zmm: [32][64]u8,
    opmask: [8]u64,

    pub fn clear(self: *AvxState) void {
        for (&self.ymm_high) |*r| {
            for (r) |*b| {
                b.* = 0;
            }
        }
        for (&self.opmask) |*m| {
            m.* = 0;
        }
    }
};
