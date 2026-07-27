//! Exception Reply

const types = @import("../types/types.zig");

const Action = types.behavior.Action;
const Context = types.context.Context;

pub const ExceptionReply = struct {
    ReplyPort: u64,
    Action: Action,
    NewContext: ?*Context,
};

pub fn createReply(reply_port: u64, action: Action) ExceptionReply {
    return ExceptionReply{
        .ReplyPort = reply_port,
        .Action = action,
        .NewContext = null,
    };
}

pub fn createReplyWithState(reply_port: u64, action: Action, context: *Context) ExceptionReply {
    return ExceptionReply{
        .ReplyPort = reply_port,
        .Action = action,
        .NewContext = context,
    };
}

pub fn sendReply(reply: *const ExceptionReply) bool {
    _ = reply;
    return true;
}

pub fn replyResume(reply_port: u64) bool {
    const reply = createReply(reply_port, .Resume);
    return sendReply(&reply);
}

pub fn replyTerminate(reply_port: u64) bool {
    const reply = createReply(reply_port, .Terminate);
    return sendReply(&reply);
}

pub fn replyTerminateCorpse(reply_port: u64) bool {
    const reply = createReply(reply_port, .TerminateCorpse);
    return sendReply(&reply);
}
