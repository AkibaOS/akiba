//! Thread Exception Ports

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const array_module = @import("array.zig");

const Port = types.Port;
const PortOwner = types.PortOwner;
const PortArray = array_module.PortArray;
const ExceptionType = constants.ExceptionType;
const Behavior = constants.Behavior;
const Flavor = constants.Flavor;

pub const max_threads = 1024;

var thread_ports: [max_threads]PortArray = init_all();

fn init_all() [max_threads]PortArray {
    var arrays: [max_threads]PortArray = undefined;
    for (&arrays) |*a| {
        a.* = PortArray.init();
    }
    return arrays;
}

pub fn get_port(thread_id: u64, exception_type: ExceptionType) *const Port {
    if (thread_id >= max_threads) {
        return &empty_port;
    }
    return thread_ports[thread_id].get_const(exception_type);
}

pub fn set_port(thread_id: u64, exception_type: ExceptionType, port_id: u64, behavior: Behavior, flavor: Flavor) bool {
    if (thread_id >= max_threads) {
        return false;
    }
    const port = Port{
        .port_id = port_id,
        .behavior = behavior,
        .flavor = flavor,
        .owner = .thread,
        .owner_id = thread_id,
        .active = true,
    };
    thread_ports[thread_id].set(exception_type, port);
    return true;
}

pub fn clear_port(thread_id: u64, exception_type: ExceptionType) bool {
    if (thread_id >= max_threads) {
        return false;
    }
    thread_ports[thread_id].get(exception_type).clear();
    return true;
}

pub fn has_port(thread_id: u64, exception_type: ExceptionType) bool {
    if (thread_id >= max_threads) {
        return false;
    }
    return thread_ports[thread_id].has_port(exception_type);
}

pub fn clear_all_for_thread(thread_id: u64) bool {
    if (thread_id >= max_threads) {
        return false;
    }
    thread_ports[thread_id].clear_all();
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
