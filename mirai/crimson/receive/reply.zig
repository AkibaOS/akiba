//! Exception Reply

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");

const Context = types.Context;
const Action = constants.Action;

pub const ExceptionReply = struct {
    reply_port: u64,
    action: Action,
    new_context: ?*Context,
};

pub fn create_reply(reply_port: u64, action: Action) ExceptionReply {
    return ExceptionReply{
        .reply_port = reply_port,
        .action = action,
        .new_context = null,
    };
}

pub fn create_reply_with_state(reply_port: u64, action: Action, context: *Context) ExceptionReply {
    return ExceptionReply{
        .reply_port = reply_port,
        .action = action,
        .new_context = context,
    };
}

pub fn send_reply(reply: *const ExceptionReply) bool {
    _ = reply;
    return true;
}

pub fn reply_resume(reply_port: u64) bool {
    const reply = create_reply(reply_port, .@"resume");
    return send_reply(&reply);
}

pub fn reply_terminate(reply_port: u64) bool {
    const reply = create_reply(reply_port, .terminate);
    return send_reply(&reply);
}

pub fn reply_terminate_corpse(reply_port: u64) bool {
    const reply = create_reply(reply_port, .terminate_corpse);
    return send_reply(&reply);
}
