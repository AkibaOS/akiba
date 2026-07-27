//! Exception Triage

const chain = @import("chain.zig");
const entry = @import("../handlers/entry.zig");
const ports = @import("../ports/ports.zig");
const types = @import("../types/types.zig");

const Action = types.behavior.Action;
const Exception = types.exception.Exception;

pub fn triage(exception: *Exception) Action {
    const handler_action = entry.dispatch(exception);

    if (handler_action == .Collapse) {
        return .Collapse;
    }

    if (handler_action == .Resume) {
        return .Resume;
    }

    const lookup_result = ports.lookup.findPort(exception);
    if (!lookup_result.Found) {
        return entry.defaultAction(exception.ExceptionType);
    }

    const port = lookup_result.Port;
    if (!port.isValid()) {
        return entry.defaultAction(exception.ExceptionType);
    }

    return chain.propagateThroughChain(exception);
}
