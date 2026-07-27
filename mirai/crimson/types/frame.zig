//! Interrupt Stack Frame

const constants = @import("../constants/constants.zig");

const privileges = constants.privileges;

pub const Frame = extern struct {
    ErrorCode: u64,
    RIP: u64,
    CS: u64,
    RFLAGS: u64,
    RSP: u64,
    SS: u64,

    pub fn isUserMode(self: *const Frame) bool {
        return (self.CS & privileges.PRIVILEGE_MASK) == privileges.USER_PRIVILEGE_LEVEL;
    }

    pub fn isKernelMode(self: *const Frame) bool {
        return (self.CS & privileges.PRIVILEGE_MASK) == privileges.KERNEL_PRIVILEGE_LEVEL;
    }
};

pub const FrameNoError = extern struct {
    RIP: u64,
    CS: u64,
    RFLAGS: u64,
    RSP: u64,
    SS: u64,
};
