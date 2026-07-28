//! Shatter Handler (Debug, Breakpoint)

const types = @import("mirai").crimson.types;

const Action = types.behavior.Action;
const Exception = types.exception.Exception;

pub fn handle(exception: *Exception) Action {
    _ = exception;
    return .Debug;
}
