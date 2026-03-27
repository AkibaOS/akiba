//! Interrupt Stack Frame

pub const Frame = extern struct {
    error_code: u64,
    rip: u64,
    cs: u64,
    rflags: u64,
    rsp: u64,
    ss: u64,
    pub fn is_user_mode(self: *const Frame) bool {
        return (self.cs & 0x3) == 3;
    }
    pub fn is_kernel_mode(self: *const Frame) bool {
        return (self.cs & 0x3) == 0;
    }
};

pub const FrameNoError = extern struct {
    rip: u64,
    cs: u64,
    rflags: u64,
    rsp: u64,
    ss: u64,
};
