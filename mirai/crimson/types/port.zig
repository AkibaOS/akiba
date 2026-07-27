//! Exception Port

const behavior = @import("behavior.zig");
const flavor = @import("flavor.zig");

pub const PortOwner = enum(u8) {
    None = 0,
    Thread = 1,
    Kata = 2,
    Host = 3,
};

pub const Port = struct {
    PortId: u64,
    Behavior: behavior.Behavior,
    Flavor: flavor.Flavor,
    Owner: PortOwner,
    OwnerId: u64,
    Active: bool,

    pub fn isValid(self: *const Port) bool {
        return self.PortId != 0 and self.Active;
    }

    pub fn clear(self: *Port) void {
        self.* = Port{ .PortId = 0, .Behavior = .Default, .Flavor = .None, .Owner = .None, .OwnerId = 0, .Active = false };
    }
};
