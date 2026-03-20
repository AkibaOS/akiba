//! Exception Identity

pub const Identity = struct {
    thread_id: u64, kata_id: u64, thread_port: u64, kata_port: u64,
    thread_name: [32]u8, kata_name: [32]u8,
    pub fn clear(self: *Identity) void { self.* = Identity{ .thread_id = 0, .kata_id = 0, .thread_port = 0, .kata_port = 0, .thread_name = [_]u8{0} ** 32, .kata_name = [_]u8{0} ** 32 }; }
    pub fn is_kernel(self: *const Identity) bool { return self.kata_id == 0; }
};
