//! Common Handler Entry

const breach = @import("mirai").crimson.handlers.breach;
const classify = @import("mirai").crimson.classify;
const collapse = @import("mirai").crimson.handlers.collapse;
const context = @import("mirai").crimson.context;
const forbidden = @import("mirai").crimson.handlers.forbidden;
const missing = @import("mirai").crimson.handlers.missing;
const overflow = @import("mirai").crimson.handlers.overflow;
const propagate = @import("mirai").crimson.propagate;
const shatter = @import("mirai").crimson.handlers.shatter;
const state = @import("mirai").crimson.state;
const types = @import("mirai").crimson.types;

const Action = types.behavior.Action;
const Context = types.context.Context;
const Exception = types.exception.Exception;
const ExceptionType = types.kind.ExceptionType;
const Frame = types.frame.Frame;

var exception_context: Context = undefined;

pub fn createException(vector: u8, frame: *Frame, registers: *Context) Exception {
    context.capture.captureFromFrame(registers, frame);
    const exception_type = classify.vector.classifyVector(vector);
    return Exception{
        .ExceptionType = exception_type,
        .Code = frame.ErrorCode,
        .Subcode = 0,
        .Vector = vector,
        .Address = registers.CR2,
        .Context = registers,
        .Frame = frame,
        .KataId = 0,
        .ThreadId = 0,
        .Recoverable = exception_type.isRecoverable(),
    };
}

pub fn getExceptionContext() *Context {
    return &exception_context;
}

pub fn defaultAction(exception_type: ExceptionType) Action {
    return switch (exception_type) {
        .Breach => .Resume,
        .Shatter => .Debug,
        .Critical, .Collapse => .Collapse,
        else => .Terminate,
    };
}

pub fn dispatch(exception: *Exception) Action {
    return switch (exception.ExceptionType) {
        .Breach => breach.handle(exception),
        .Forbidden => forbidden.handle(exception),
        .Overflow => overflow.handle(exception),
        .Shatter => shatter.handle(exception),
        .Missing => missing.handle(exception),
        .Collapse => collapse.handle(exception),
        .Critical => .Collapse,
        else => .Terminate,
    };
}

pub fn handleException(vector: u8, frame: *Frame, registers: *Context) Action {
    var exception = createException(vector, frame, registers);
    state.recordException(exception.ExceptionType, exception.Address);
    return propagate.triage.triage(&exception);
}
