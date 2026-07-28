//! Raise Resource Exception

const entry = @import("mirai").crimson.handlers.entry;
const propagate = @import("mirai").crimson.propagate;
const types = @import("mirai").crimson.types;

const Action = types.behavior.Action;
const Exception = types.exception.Exception;
const ResourceCode = types.codes.ResourceCode;

pub fn raiseMemoryLimit(kata_id: u64, thread_id: u64, requested: u64, limit: u64) Action {
    return raiseResource(.MemoryLimit, kata_id, thread_id, requested, limit);
}

pub fn raiseCpuLimit(kata_id: u64, thread_id: u64, used: u64, limit: u64) Action {
    return raiseResource(.CpuLimit, kata_id, thread_id, used, limit);
}

pub fn raiseFileLimit(kata_id: u64, thread_id: u64, count: u64, limit: u64) Action {
    return raiseResource(.FileLimit, kata_id, thread_id, count, limit);
}

fn raiseResource(resource_code: ResourceCode, kata_id: u64, thread_id: u64, code: u64, subcode: u64) Action {
    var context = entry.getExceptionContext();
    context.clear();

    var exception = Exception{
        .ExceptionType = .Resource,
        .Code = code,
        .Subcode = subcode,
        .Vector = 0,
        .Address = 0,
        .Context = context,
        .Frame = undefined,
        .KataId = kata_id,
        .ThreadId = thread_id,
        .Recoverable = true,
    };

    _ = resource_code;

    return propagate.triage.triage(&exception);
}
