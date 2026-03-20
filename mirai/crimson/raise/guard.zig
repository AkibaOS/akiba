//! Raise Guard Exception

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const handlers = @import("../handlers/handlers.zig");
const propagate = @import("../propagate/propagate.zig");

const Exception = types.Exception;
const ExceptionType = constants.ExceptionType;
const GuardCode = constants.GuardCode;
const Action = constants.Action;

pub fn raise_port_guard(kata_id: u64, thread_id: u64, port_id: u64, operation: u64) Action {
    return raise_guard(.port_guard, kata_id, thread_id, port_id, operation);
}

pub fn raise_file_guard(kata_id: u64, thread_id: u64, file_id: u64, operation: u64) Action {
    return raise_guard(.file_guard, kata_id, thread_id, file_id, operation);
}

pub fn raise_memory_guard(kata_id: u64, thread_id: u64, address: u64, operation: u64) Action {
    return raise_guard(.memory_guard, kata_id, thread_id, address, operation);
}

fn raise_guard(guard_code: GuardCode, kata_id: u64, thread_id: u64, code: u64, subcode: u64) Action {
    var context = handlers.get_exception_context();
    context.clear();

    var exception = Exception{
        .exception_type = .guard,
        .code = code,
        .subcode = subcode,
        .vector = 0,
        .address = code,
        .context = context,
        .frame = undefined,
        .kata_id = kata_id,
        .thread_id = thread_id,
        .recoverable = true,
    };

    _ = guard_code;

    return propagate.triage(&exception);
}
