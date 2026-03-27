//! CPU Context

pub const Context = extern struct {
    rax: u64 = 0,
    rbx: u64 = 0,
    rcx: u64 = 0,
    rdx: u64 = 0,
    rsi: u64 = 0,
    rdi: u64 = 0,
    rbp: u64 = 0,
    rsp: u64 = 0,
    r8: u64 = 0,
    r9: u64 = 0,
    r10: u64 = 0,
    r11: u64 = 0,
    r12: u64 = 0,
    r13: u64 = 0,
    r14: u64 = 0,
    r15: u64 = 0,
    rip: u64 = 0,
    rflags: u64 = 0,
    cs: u16 = 0,
    ds: u16 = 0,
    es: u16 = 0,
    fs: u16 = 0,
    gs: u16 = 0,
    ss: u16 = 0,
    padding: u32 = 0,
    cr0: u64 = 0,
    cr2: u64 = 0,
    cr3: u64 = 0,
    cr4: u64 = 0,

    pub fn clear(self: *Context) void {
        self.* = Context{};
    }

    pub fn is_user_mode(self: *const Context) bool {
        return (self.cs & 0x3) == 3;
    }
    pub fn is_kernel_mode(self: *const Context) bool {
        return (self.cs & 0x3) == 0;
    }
    pub fn get_fault_address(self: *const Context) u64 {
        return self.cr2;
    }
};
