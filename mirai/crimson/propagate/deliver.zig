//! Exception Delivery

const types = @import("mirai").crimson.types;

const Behavior = types.behavior.Behavior;
const Exception = types.exception.Exception;
const ExceptionMessage = types.propagate.message.ExceptionMessage;
const Flavor = types.flavor.Flavor;
const Port = types.port.Port;

pub fn sendException(exception: *Exception, port: *const Port) bool {
    if (!port.isValid()) {
        return false;
    }

    var message = buildMessage(exception, port.Behavior, port.Flavor);
    return sendToPort(port.PortId, &message);
}

fn buildMessage(exception: *Exception, behavior: Behavior, flavor: Flavor) ExceptionMessage {
    var message = ExceptionMessage{
        .ExceptionType = @intFromEnum(exception.ExceptionType),
        .Code = exception.Code,
        .Subcode = exception.Subcode,
        .ThreadId = exception.ThreadId,
        .KataId = exception.KataId,
        .Context = null,
        .Identity = null,
    };

    if (behavior.includesState()) {
        if (flavor.includesGeneral()) {
            message.Context = exception.Context;
        }
    }

    return message;
}

fn sendToPort(port_id: u64, message: *const ExceptionMessage) bool {
    _ = port_id;
    _ = message;
    return true;
}
