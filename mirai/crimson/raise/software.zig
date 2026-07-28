//! Raise Software Exception

const entry = @import("mirai").crimson.handlers.entry;
const propagate = @import("mirai").crimson.propagate;
const types = @import("mirai").crimson.types;

const Action = types.behavior.Action;
const Exception = types.exception.Exception;
const SoftwareCode = types.codes.SoftwareCode;

pub fn raiseAssertion(kata_id: u64, thread_id: u64, address: u64) Action {
    return raiseSoftware(.Assertion, kata_id, thread_id, address, 0);
}

pub fn raiseAbort(kata_id: u64, thread_id: u64) Action {
    return raiseSoftware(.Abort, kata_id, thread_id, 0, 0);
}

pub fn raiseUserDefined(kata_id: u64, thread_id: u64, code: u64, subcode: u64) Action {
    return raiseSoftware(.UserDefined, kata_id, thread_id, code, subcode);
}

fn raiseSoftware(software_code: SoftwareCode, kata_id: u64, thread_id: u64, code: u64, subcode: u64) Action {
    var context = entry.getExceptionContext();
    context.clear();

    var exception = Exception{
        .ExceptionType = .Software,
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

    _ = software_code;

    return propagate.triage.triage(&exception);
}
