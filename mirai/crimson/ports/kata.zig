//! Kata Exception Ports

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const array_module = @import("array.zig");

const Port = types.Port;
const PortOwner = types.PortOwner;
const PortArray = array_module.PortArray;
const ExceptionType = constants.ExceptionType;
const Behavior = constants.Behavior;
const Flavor = constants.Flavor;

pub const max_katas = 256;

var kata_ports: [max_katas]PortArray = init_all();

fn init_all() [max_katas]PortArray {
    var arrays: [max_katas]PortArray = undefined;
    for (&arrays) |*a| {
        a.* = PortArray.init();
    }
    return arrays;
}

pub fn get_port(kata_id: u64, exception_type: ExceptionType) *const Port {
    if (kata_id >= max_katas) {
        return &empty_port;
    }
    return kata_ports[kata_id].get_const(exception_type);
}

pub fn set_port(kata_id: u64, exception_type: ExceptionType, port_id: u64, behavior: Behavior, flavor: Flavor) bool {
    if (kata_id >= max_katas) {
        return false;
    }
    const port = Port{
        .port_id = port_id,
        .behavior = behavior,
        .flavor = flavor,
        .owner = .kata,
        .owner_id = kata_id,
        .active = true,
    };
    kata_ports[kata_id].set(exception_type, port);
    return true;
}

pub fn clear_port(kata_id: u64, exception_type: ExceptionType) bool {
    if (kata_id >= max_katas) {
        return false;
    }
    kata_ports[kata_id].get(exception_type).clear();
    return true;
}

pub fn has_port(kata_id: u64, exception_type: ExceptionType) bool {
    if (kata_id >= max_katas) {
        return false;
    }
    return kata_ports[kata_id].has_port(exception_type);
}

pub fn clear_all_for_kata(kata_id: u64) bool {
    if (kata_id >= max_katas) {
        return false;
    }
    kata_ports[kata_id].clear_all();
    return true;
}

var empty_port: Port = Port{
    .port_id = 0,
    .behavior = .default,
    .flavor = .none,
    .owner = .none,
    .owner_id = 0,
    .active = false,
};
