//! Exception Chain (Thread → Kata → Host)

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const handlers = @import("../handlers/handlers.zig");
const ports = @import("../ports/ports.zig");
const deliver = @import("deliver.zig");
const wait = @import("wait.zig");

const Exception = types.Exception;
const Port = types.Port;
const Action = constants.Action;
const ExceptionType = constants.ExceptionType;

pub fn propagate_through_chain(exception: *Exception) Action {
    if (try_thread_port(exception)) |action| {
        return action;
    }

    if (try_kata_port(exception)) |action| {
        return action;
    }

    if (try_host_port(exception)) |action| {
        return action;
    }

    return handlers.default_action(exception.exception_type);
}

fn try_thread_port(exception: *Exception) ?Action {
    if (!ports.thread.has_port(exception.thread_id, exception.exception_type)) {
        return null;
    }

    const port = ports.thread.get_port(exception.thread_id, exception.exception_type);
    return deliver_and_wait(exception, port);
}

fn try_kata_port(exception: *Exception) ?Action {
    if (!ports.kata.has_port(exception.kata_id, exception.exception_type)) {
        return null;
    }

    const port = ports.kata.get_port(exception.kata_id, exception.exception_type);
    return deliver_and_wait(exception, port);
}

fn try_host_port(exception: *Exception) ?Action {
    if (!ports.host.has_port(exception.exception_type)) {
        return null;
    }

    const port = ports.host.get_port(exception.exception_type);
    return deliver_and_wait(exception, port);
}

fn deliver_and_wait(exception: *Exception, port: *const Port) Action {
    if (!deliver.send_exception(exception, port)) {
        return handlers.default_action(exception.exception_type);
    }

    return wait.wait_for_reply(exception, port);
}
