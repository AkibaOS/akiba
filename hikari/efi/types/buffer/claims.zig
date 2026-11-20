//! Hikari EFI Pool And Aligned Buffer Types

pub const PoolClaim = struct {
    Allocation: ?[*]align(8) u8 = null,
    Untrusted: bool = false,

    pub fn isEmpty(self: PoolClaim) bool {
        return self.Allocation == null and !self.Untrusted;
    }
};

pub const AlignedBuffer = struct {
    Pool: PoolClaim = .{},
    Data: [*]align(8) u8 = undefined,
    Size: usize = 0,
};
