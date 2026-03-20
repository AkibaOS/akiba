//! Exception Port

const constants = @import("../constants/constants.zig");
const Behavior = constants.Behavior;
const Flavor = constants.Flavor;

pub const PortOwner = enum(u8) { none = 0, thread = 1, kata = 2, host = 3 };

pub const Port = struct {
    port_id: u64, behavior: Behavior, flavor: Flavor, owner: PortOwner, owner_id: u64, active: bool,
    pub fn is_valid(self: *const Port) bool { return self.port_id != 0 and self.active; }
    pub fn clear(self: *Port) void { self.* = Port{ .port_id = 0, .behavior = .default, .flavor = .none, .owner = .none, .owner_id = 0, .active = false }; }
};

pub fn create_port(port_id: u64, owner: PortOwner, owner_id: u64) Port {
    return Port{ .port_id = port_id, .behavior = .default, .flavor = .general, .owner = owner, .owner_id = owner_id, .active = true };
}
