//! Kata Exception Ports

const array = @import("mirai").crimson.ports.array;
const constants = @import("mirai").crimson.constants;
const types = @import("mirai").crimson.types;

const limits = constants.limits;

const Behavior = types.behavior.Behavior;
const ExceptionType = types.kind.ExceptionType;
const Flavor = types.flavor.Flavor;
const Port = types.port.Port;
const PortArray = array.PortArray;

var kata_ports: [limits.MAX_KATAS]PortArray = initAll();

fn initAll() [limits.MAX_KATAS]PortArray {
    var arrays: [limits.MAX_KATAS]PortArray = undefined;
    for (&arrays) |*port_array| {
        port_array.* = PortArray.init();
    }
    return arrays;
}

pub fn getPort(kata_id: u64, exception_type: ExceptionType) *const Port {
    if (kata_id >= limits.MAX_KATAS) {
        return &empty_port;
    }
    return kata_ports[kata_id].getConst(exception_type);
}

pub fn setPort(kata_id: u64, exception_type: ExceptionType, port_id: u64, behavior: Behavior, flavor: Flavor) bool {
    if (kata_id >= limits.MAX_KATAS) {
        return false;
    }
    const port = Port{
        .PortId = port_id,
        .Behavior = behavior,
        .Flavor = flavor,
        .Owner = .Kata,
        .OwnerId = kata_id,
        .Active = true,
    };
    kata_ports[kata_id].set(exception_type, port);
    return true;
}

pub fn clearPort(kata_id: u64, exception_type: ExceptionType) bool {
    if (kata_id >= limits.MAX_KATAS) {
        return false;
    }
    kata_ports[kata_id].get(exception_type).clear();
    return true;
}

pub fn hasPort(kata_id: u64, exception_type: ExceptionType) bool {
    if (kata_id >= limits.MAX_KATAS) {
        return false;
    }
    return kata_ports[kata_id].hasPort(exception_type);
}

pub fn clearAllForKata(kata_id: u64) bool {
    if (kata_id >= limits.MAX_KATAS) {
        return false;
    }
    kata_ports[kata_id].clearAll();
    return true;
}

var empty_port: Port = Port{
    .PortId = 0,
    .Behavior = .Default,
    .Flavor = .None,
    .Owner = .None,
    .OwnerId = 0,
    .Active = false,
};
