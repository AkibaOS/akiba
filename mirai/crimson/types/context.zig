//! CPU Context

const constants = @import("mirai").crimson.constants;

const privileges = constants.privileges;

pub const Context = extern struct {
    RAX: u64 = 0,
    RBX: u64 = 0,
    RCX: u64 = 0,
    RDX: u64 = 0,
    RSI: u64 = 0,
    RDI: u64 = 0,
    RBP: u64 = 0,
    RSP: u64 = 0,
    R8: u64 = 0,
    R9: u64 = 0,
    R10: u64 = 0,
    R11: u64 = 0,
    R12: u64 = 0,
    R13: u64 = 0,
    R14: u64 = 0,
    R15: u64 = 0,
    RIP: u64 = 0,
    RFLAGS: u64 = 0,
    CS: u16 = 0,
    DS: u16 = 0,
    ES: u16 = 0,
    FS: u16 = 0,
    GS: u16 = 0,
    SS: u16 = 0,
    Padding: u32 = 0,
    CR0: u64 = 0,
    CR2: u64 = 0,
    CR3: u64 = 0,
    CR4: u64 = 0,

    pub fn clear(self: *Context) void {
        self.* = Context{};
    }

    pub fn isUserMode(self: *const Context) bool {
        return (self.CS & privileges.PRIVILEGE_MASK) == privileges.USER_PRIVILEGE_LEVEL;
    }

    pub fn isKernelMode(self: *const Context) bool {
        return (self.CS & privileges.PRIVILEGE_MASK) == privileges.KERNEL_PRIVILEGE_LEVEL;
    }

    pub fn getFaultAddress(self: *const Context) u64 {
        return self.CR2;
    }
};
