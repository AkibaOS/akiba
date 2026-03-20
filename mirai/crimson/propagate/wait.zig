//! Wait for Exception Reply

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const handlers = @import("../handlers/handlers.zig");

const Exception = types.Exception;
const Port = types.Port;
const Action = constants.Action;

pub const Reply = struct {
    action: Action,
    new_state: bool,
    valid: bool,
};

pub fn wait_for_reply(exception: *Exception, port: *const Port) Action {
    _ = port;

    const reply = receive_reply();

    if (!reply.valid) {
        return handlers.default_action(exception.exception_type);
    }

    if (reply.new_state) {
        apply_new_state(exception);
    }

    return reply.action;
}

fn receive_reply() Reply {
    return Reply{
        .action = .terminate,
        .new_state = false,
        .valid = true,
    };
}

fn apply_new_state(exception: *Exception) void {
    _ = exception;
}

pub fn wait_with_timeout(exception: *Exception, port: *const Port, timeout_ms: u64) Action {
    _ = timeout_ms;
    return wait_for_reply(exception, port);
}
