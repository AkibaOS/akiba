//! Sparse Kata Exception Ports

const strings = @import("mirai").crimson.strings.ports;
const types = @import("mirai").crimson.types;

const Behavior = types.behavior.Behavior;
const ExceptionType = types.kind.ExceptionType;
const Flavor = types.flavor.Flavor;
const Port = types.port.Port;
const Registry = types.ports.registry.Registry;

var registry: Registry = .{};

pub fn getPort(kata_id: u64, exception_type: ExceptionType) *const Port {
    return registry.getPort(kata_id, exception_type);
}

pub fn setPort(kata_id: u64, exception_type: ExceptionType, port_id: u64, behavior: Behavior, flavor: Flavor) bool {
    const port = Port{
        .PortId = port_id,
        .Behavior = behavior,
        .Flavor = flavor,
        .Owner = .Kata,
        .OwnerId = kata_id,
        .Active = true,
    };
    return registry.setPort(kata_id, exception_type, port, strings.KATA_POOL);
}

pub fn clearPort(kata_id: u64, exception_type: ExceptionType) bool {
    return registry.clearPort(kata_id, exception_type);
}

pub fn hasPort(kata_id: u64, exception_type: ExceptionType) bool {
    return registry.hasPort(kata_id, exception_type);
}

pub fn clearAllForKata(kata_id: u64) bool {
    return registry.clearAll(kata_id);
}
