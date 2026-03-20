//! Raise Software Exception

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const handlers = @import("../handlers/handlers.zig");
const propagate = @import("../propagate/propagate.zig");

const Exception = types.Exception;
const Context = types.Context;
const ExceptionType = constants.ExceptionType;
const SoftwareCode = constants.SoftwareCode;
const Action = constants.Action;

pub fn raise_assertion(kata_id: u64, thread_id: u64, address: u64) Action {
    return raise_software(.assertion, kata_id, thread_id, address, 0);
}

pub fn raise_abort(kata_id: u64, thread_id: u64) Action {
    return raise_software(.abort, kata_id, thread_id, 0, 0);
}

pub fn raise_user_defined(kata_id: u64, thread_id: u64, code: u64, subcode: u64) Action {
    return raise_software(.user_defined, kata_id, thread_id, code, subcode);
}

fn raise_software(software_code: SoftwareCode, kata_id: u64, thread_id: u64, code: u64, subcode: u64) Action {
    var context = handlers.get_exception_context();
    context.clear();

    var exception = Exception{
        .exception_type = .software,
        .code = code,
        .subcode = subcode,
        .vector = 0,
        .address = 0,
        .context = context,
        .frame = undefined,
        .kata_id = kata_id,
        .thread_id = thread_id,
        .recoverable = true,
    };

    _ = software_code;

    return propagate.triage(&exception);
}
