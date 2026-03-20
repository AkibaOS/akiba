//! Exception Triage

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const handlers = @import("../handlers/handlers.zig");
const ports = @import("../ports/ports.zig");
const chain = @import("chain.zig");
const deliver = @import("deliver.zig");

const Exception = types.Exception;
const Action = constants.Action;

pub fn triage(exception: *Exception) Action {
    const handler_action = handlers.dispatch(exception);

    if (handler_action == .collapse) {
        return .collapse;
    }

    if (handler_action == .@"resume") {
        return .@"resume";
    }

    const lookup_result = ports.find_port(exception);
    if (!lookup_result.found) {
        return handlers.default_action(exception.exception_type);
    }

    const port = lookup_result.port;
    if (!port.is_valid()) {
        return handlers.default_action(exception.exception_type);
    }

    return chain.propagate_through_chain(exception);
}
