//! Crimson Classification And Action Codec Checks

const crimson = @import("mirai").crimson;
const inputs = @import("tests").constants.crimson;
const labels = @import("tests").strings.crimson;
const verify = @import("tests").verify;

pub fn run() void {
    for (inputs.VECTORS) |fixture| {
        verify.require(crimson.classify.vector.classifyVector(fixture.Number) == fixture.Kind and
            crimson.classify.vector.vectorHasErrorCode(fixture.Number) == fixture.ErrorCode, labels.VECTORS);
    }
    verify.require(crimson.classify.vector.isExceptionVector(31) and
        !crimson.classify.vector.isExceptionVector(32) and !crimson.classify.vector.isExceptionVector(255), labels.BOUNDS);
    for (inputs.ACTIONS) |fixture| {
        const parsed = crimson.receive.actions.parseActionCode(fixture.Code);
        verify.require(parsed.Valid and parsed.Action == fixture.Action and parsed.ModifyState == fixture.Modify and
            parsed.NewContext == null and crimson.receive.actions.encodeAction(fixture.Action, fixture.Modify) == fixture.Code, labels.ACTIONS);
    }
    const invalid = crimson.receive.actions.parseActionCode(inputs.INVALID_ACTION);
    verify.require(!invalid.Valid and !invalid.ModifyState and invalid.Action == .Terminate and invalid.NewContext == null, labels.INVALID_ACTION);
}
