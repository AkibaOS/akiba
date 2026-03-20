//! Single Port Operations

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const Port = types.Port;
const PortOwner = types.PortOwner;
const Behavior = constants.Behavior;
const Flavor = constants.Flavor;

pub fn create(port_id: u64, owner: PortOwner, owner_id: u64) Port {
    return Port{ .port_id = port_id, .behavior = .default, .flavor = .general, .owner = owner, .owner_id = owner_id, .active = true };
}

pub fn set_behavior(port: *Port, behavior: Behavior) void { port.behavior = behavior; }
pub fn set_flavor(port: *Port, flavor: Flavor) void { port.flavor = flavor; }
pub fn activate(port: *Port) void { port.active = true; }
pub fn deactivate(port: *Port) void { port.active = false; }
