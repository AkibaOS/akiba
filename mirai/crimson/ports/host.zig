//! Host Exception Port

const array = @import("mirai").crimson.ports.array;
const types = @import("mirai").crimson.types;

const Behavior = types.behavior.Behavior;
const ExceptionType = types.kind.ExceptionType;
const Flavor = types.flavor.Flavor;
const Port = types.port.Port;
const PortArray = array.PortArray;

var host_ports: PortArray = PortArray.init();

pub fn getPort(exception_type: ExceptionType) *const Port {
    return host_ports.getConst(exception_type);
}

pub fn setPort(exception_type: ExceptionType, port_id: u64, behavior: Behavior, flavor: Flavor) void {
    const port = Port{
        .PortId = port_id,
        .Behavior = behavior,
        .Flavor = flavor,
        .Owner = .Host,
        .OwnerId = 0,
        .Active = true,
    };
    host_ports.set(exception_type, port);
}

pub fn clearPort(exception_type: ExceptionType) void {
    host_ports.get(exception_type).clear();
}

pub fn hasPort(exception_type: ExceptionType) bool {
    return host_ports.hasPort(exception_type);
}

pub fn clearAll() void {
    host_ports.clearAll();
}
