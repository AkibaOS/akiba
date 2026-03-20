//! Exception Delivery

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const context_ops = @import("../context/context.zig");

const Exception = types.Exception;
const Port = types.Port;
const Context = types.Context;
const FloatState = types.FloatState;
const Identity = types.Identity;
const Behavior = constants.Behavior;
const Flavor = constants.Flavor;

pub const ExceptionMessage = struct {
    exception_type: u8,
    code: u64,
    subcode: u64,
    thread_id: u64,
    kata_id: u64,
    context: ?*Context,
    identity: ?*Identity,
};

pub fn send_exception(exception: *Exception, port: *const Port) bool {
    if (!port.is_valid()) {
        return false;
    }

    var message = build_message(exception, port.behavior, port.flavor);
    return send_to_port(port.port_id, &message);
}

fn build_message(exception: *Exception, behavior: Behavior, flavor: Flavor) ExceptionMessage {
    var message = ExceptionMessage{
        .exception_type = @intFromEnum(exception.exception_type),
        .code = exception.code,
        .subcode = exception.subcode,
        .thread_id = exception.thread_id,
        .kata_id = exception.kata_id,
        .context = null,
        .identity = null,
    };

    if (behavior.includes_state()) {
        if (flavor.includes_general()) {
            message.context = exception.context;
        }
    }

    return message;
}

fn send_to_port(port_id: u64, message: *const ExceptionMessage) bool {
    _ = port_id;
    _ = message;
    return true;
}
