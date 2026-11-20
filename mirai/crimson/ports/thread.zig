//! Sparse Thread Exception Ports

const strings = @import("mirai").crimson.strings.ports.report;
const types = @import("mirai").crimson.types;

const Behavior = types.behavior.Behavior;
const ExceptionType = types.kind.ExceptionType;
const Flavor = types.flavor.Flavor;
const Port = types.port.Port;
const Registry = types.ports.registry.Registry;

var registry: Registry = .{};

pub fn getPort(thread_id: u64, exception_type: ExceptionType) *const Port {
    return registry.getPort(thread_id, exception_type);
}

pub fn setPort(thread_id: u64, exception_type: ExceptionType, port_id: u64, behavior: Behavior, flavor: Flavor) bool {
    const port = Port{
        .PortId = port_id,
        .Behavior = behavior,
        .Flavor = flavor,
        .Owner = .Thread,
        .OwnerId = thread_id,
        .Active = true,
    };
    return registry.setPort(thread_id, exception_type, port, strings.THREAD_POOL);
}

pub fn clearPort(thread_id: u64, exception_type: ExceptionType) bool {
    return registry.clearPort(thread_id, exception_type);
}

pub fn hasPort(thread_id: u64, exception_type: ExceptionType) bool {
    return registry.hasPort(thread_id, exception_type);
}

pub fn clearAllForThread(thread_id: u64) bool {
    return registry.clearAll(thread_id);
}
