//! Exception Identity

const constants = @import("mirai").crimson.constants;

const limits = constants.limits;

pub const Identity = struct {
    ThreadId: u64,
    KataId: u64,
    ThreadPort: u64,
    KataPort: u64,
    ThreadName: [limits.IDENTITY_NAME_CAPACITY]u8,
    KataName: [limits.IDENTITY_NAME_CAPACITY]u8,

    pub fn clear(self: *Identity) void {
        self.* = Identity{
            .ThreadId = 0,
            .KataId = 0,
            .ThreadPort = 0,
            .KataPort = 0,
            .ThreadName = [_]u8{0} ** limits.IDENTITY_NAME_CAPACITY,
            .KataName = [_]u8{0} ** limits.IDENTITY_NAME_CAPACITY,
        };
    }

    pub fn isKernel(self: *const Identity) bool {
        return self.KataId == 0;
    }
};
