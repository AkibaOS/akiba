//! Wait for Exception Reply

const entry = @import("../handlers/entry.zig");
const types = @import("../types/types.zig");

const Action = types.behavior.Action;
const Exception = types.exception.Exception;
const Port = types.port.Port;

pub const Reply = struct {
    Action: Action,
    NewState: bool,
    Valid: bool,
};

pub fn waitForReply(exception: *Exception, port: *const Port) Action {
    _ = port;

    const reply = receiveReply();

    if (!reply.Valid) {
        return entry.defaultAction(exception.ExceptionType);
    }

    if (reply.NewState) {
        applyNewState(exception);
    }

    return reply.Action;
}

fn receiveReply() Reply {
    return Reply{
        .Action = .Terminate,
        .NewState = false,
        .Valid = true,
    };
}

fn applyNewState(exception: *Exception) void {
    _ = exception;
}

pub fn waitWithTimeout(exception: *Exception, port: *const Port, timeout_ms: u64) Action {
    _ = timeout_ms;
    return waitForReply(exception, port);
}
