//! Thread Exception Ports

const array = @import("mirai").crimson.ports.array;
const constants = @import("mirai").crimson.constants;
const types = @import("mirai").crimson.types;

const limits = constants.limits;

const Behavior = types.behavior.Behavior;
const ExceptionType = types.kind.ExceptionType;
const Flavor = types.flavor.Flavor;
const Port = types.port.Port;
const PortArray = array.PortArray;

var thread_ports: [limits.MAX_THREADS]PortArray = initAll();

fn initAll() [limits.MAX_THREADS]PortArray {
    var arrays: [limits.MAX_THREADS]PortArray = undefined;
    for (&arrays) |*port_array| {
        port_array.* = PortArray.init();
    }
    return arrays;
}

pub fn getPort(thread_id: u64, exception_type: ExceptionType) *const Port {
    if (thread_id >= limits.MAX_THREADS) {
        return &empty_port;
    }
    return thread_ports[thread_id].getConst(exception_type);
}

pub fn setPort(thread_id: u64, exception_type: ExceptionType, port_id: u64, behavior: Behavior, flavor: Flavor) bool {
    if (thread_id >= limits.MAX_THREADS) {
        return false;
    }
    const port = Port{
        .PortId = port_id,
        .Behavior = behavior,
        .Flavor = flavor,
        .Owner = .Thread,
        .OwnerId = thread_id,
        .Active = true,
    };
    thread_ports[thread_id].set(exception_type, port);
    return true;
}

pub fn clearPort(thread_id: u64, exception_type: ExceptionType) bool {
    if (thread_id >= limits.MAX_THREADS) {
        return false;
    }
    thread_ports[thread_id].get(exception_type).clear();
    return true;
}

pub fn hasPort(thread_id: u64, exception_type: ExceptionType) bool {
    if (thread_id >= limits.MAX_THREADS) {
        return false;
    }
    return thread_ports[thread_id].hasPort(exception_type);
}

pub fn clearAllForThread(thread_id: u64) bool {
    if (thread_id >= limits.MAX_THREADS) {
        return false;
    }
    thread_ports[thread_id].clearAll();
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
