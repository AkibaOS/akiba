//! Single Port Operations

const types = @import("mirai").crimson.types;

const Behavior = types.behavior.Behavior;
const Flavor = types.flavor.Flavor;
const Port = types.port.Port;
const PortOwner = types.port.PortOwner;

pub fn create(port_id: u64, owner: PortOwner, owner_id: u64) Port {
    return Port{ .PortId = port_id, .Behavior = .Default, .Flavor = .General, .Owner = owner, .OwnerId = owner_id, .Active = true };
}

pub fn setBehavior(port: *Port, behavior: Behavior) void {
    port.Behavior = behavior;
}

pub fn setFlavor(port: *Port, flavor: Flavor) void {
    port.Flavor = flavor;
}

pub fn activate(port: *Port) void {
    port.Active = true;
}

pub fn deactivate(port: *Port) void {
    port.Active = false;
}
