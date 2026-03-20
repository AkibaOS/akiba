//! Host Exception Port

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const array_module = @import("array.zig");

const Port = types.Port;
const PortOwner = types.PortOwner;
const PortArray = array_module.PortArray;
const ExceptionType = constants.ExceptionType;
const Behavior = constants.Behavior;
const Flavor = constants.Flavor;

var host_ports: PortArray = PortArray.init();

pub fn get_port(exception_type: ExceptionType) *const Port {
    return host_ports.get_const(exception_type);
}

pub fn set_port(exception_type: ExceptionType, port_id: u64, behavior: Behavior, flavor: Flavor) void {
    const port = Port{
        .port_id = port_id,
        .behavior = behavior,
        .flavor = flavor,
        .owner = .host,
        .owner_id = 0,
        .active = true,
    };
    host_ports.set(exception_type, port);
}

pub fn clear_port(exception_type: ExceptionType) void {
    host_ports.get(exception_type).clear();
}

pub fn has_port(exception_type: ExceptionType) bool {
    return host_ports.has_port(exception_type);
}

pub fn clear_all() void {
    host_ports.clear_all();
}
