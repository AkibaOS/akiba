//! Exception Chain (Thread → Kata → Host)

const deliver = @import("mirai").crimson.propagate.deliver;
const entry = @import("mirai").crimson.handlers.entry;
const ports = @import("mirai").crimson.ports;
const types = @import("mirai").crimson.types;
const wait = @import("mirai").crimson.propagate.wait;

const Action = types.behavior.Action;
const Exception = types.exception.Exception;
const Port = types.port.Port;

pub fn propagateThroughChain(exception: *Exception) Action {
    if (tryThreadPort(exception)) |action| {
        return action;
    }

    if (tryKataPort(exception)) |action| {
        return action;
    }

    if (tryHostPort(exception)) |action| {
        return action;
    }

    return entry.defaultAction(exception.ExceptionType);
}

fn tryThreadPort(exception: *Exception) ?Action {
    if (!ports.thread.hasPort(exception.ThreadId, exception.ExceptionType)) {
        return null;
    }

    const port = ports.thread.getPort(exception.ThreadId, exception.ExceptionType);
    return deliverAndWait(exception, port);
}

fn tryKataPort(exception: *Exception) ?Action {
    if (!ports.kata.hasPort(exception.KataId, exception.ExceptionType)) {
        return null;
    }

    const port = ports.kata.getPort(exception.KataId, exception.ExceptionType);
    return deliverAndWait(exception, port);
}

fn tryHostPort(exception: *Exception) ?Action {
    if (!ports.host.hasPort(exception.ExceptionType)) {
        return null;
    }

    const port = ports.host.getPort(exception.ExceptionType);
    return deliverAndWait(exception, port);
}

fn deliverAndWait(exception: *Exception, port: *const Port) Action {
    if (!deliver.sendException(exception, port)) {
        return entry.defaultAction(exception.ExceptionType);
    }

    return wait.waitForReply(exception, port);
}
