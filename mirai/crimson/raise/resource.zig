//! Raise Resource Exception

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const handlers = @import("../handlers/handlers.zig");
const propagate = @import("../propagate/propagate.zig");

const Exception = types.Exception;
const ExceptionType = constants.ExceptionType;
const ResourceCode = constants.ResourceCode;
const Action = constants.Action;

pub fn raise_memory_limit(kata_id: u64, thread_id: u64, requested: u64, limit: u64) Action {
    return raise_resource(.memory_limit, kata_id, thread_id, requested, limit);
}

pub fn raise_cpu_limit(kata_id: u64, thread_id: u64, used: u64, limit: u64) Action {
    return raise_resource(.cpu_limit, kata_id, thread_id, used, limit);
}

pub fn raise_file_limit(kata_id: u64, thread_id: u64, count: u64, limit: u64) Action {
    return raise_resource(.file_limit, kata_id, thread_id, count, limit);
}

fn raise_resource(resource_code: ResourceCode, kata_id: u64, thread_id: u64, code: u64, subcode: u64) Action {
    var context = handlers.get_exception_context();
    context.clear();

    var exception = Exception{
        .exception_type = .resource,
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

    _ = resource_code;

    return propagate.triage(&exception);
}
