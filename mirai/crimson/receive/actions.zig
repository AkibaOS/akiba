//! Parse Reply Actions

const constants = @import("mirai").crimson.constants;
const types = @import("mirai").crimson.types;

const replies = constants.replies;

const Action = types.behavior.Action;
const Context = types.context.Context;

pub const ParsedAction = struct {
    Action: Action,
    ModifyState: bool,
    NewContext: ?*Context,
    Valid: bool,
};

pub fn parseActionCode(code: u64) ParsedAction {
    const action_value: u8 = @truncate(code & replies.ACTION_MASK);
    const flags: u8 = @truncate((code >> replies.FLAGS_SHIFT) & replies.ACTION_MASK);

    const action: Action = switch (action_value) {
        @intFromEnum(Action.Resume) => .Resume,
        @intFromEnum(Action.Skip) => .Skip,
        @intFromEnum(Action.Terminate) => .Terminate,
        @intFromEnum(Action.TerminateCorpse) => .TerminateCorpse,
        @intFromEnum(Action.Collapse) => .Collapse,
        @intFromEnum(Action.Debug) => .Debug,
        else => return ParsedAction{
            .Action = .Terminate,
            .ModifyState = false,
            .NewContext = null,
            .Valid = false,
        },
    };

    return ParsedAction{
        .Action = action,
        .ModifyState = (flags & replies.MODIFY_STATE_FLAG) != 0,
        .NewContext = null,
        .Valid = true,
    };
}

pub fn encodeAction(action: Action, modify_state: bool) u64 {
    var code: u64 = @intFromEnum(action);
    if (modify_state) {
        code |= (@as(u64, replies.MODIFY_STATE_FLAG) << replies.FLAGS_SHIFT);
    }
    return code;
}
