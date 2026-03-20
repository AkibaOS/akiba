//! Parse Reply Actions

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");

const Context = types.Context;
const Action = constants.Action;

pub const ParsedAction = struct {
    action: Action,
    modify_state: bool,
    new_context: ?*Context,
    valid: bool,
};

pub fn parse_action_code(code: u64) ParsedAction {
    const action_value: u8 = @truncate(code & 0xFF);
    const flags: u8 = @truncate((code >> 8) & 0xFF);

    const action: Action = switch (action_value) {
        0 => .@"resume",
        1 => .skip,
        2 => .terminate,
        3 => .terminate_corpse,
        4 => .collapse,
        5 => .debug,
        else => return ParsedAction{
            .action = .terminate,
            .modify_state = false,
            .new_context = null,
            .valid = false,
        },
    };

    return ParsedAction{
        .action = action,
        .modify_state = (flags & 1) != 0,
        .new_context = null,
        .valid = true,
    };
}

pub fn encode_action(action: Action, modify_state: bool) u64 {
    var code: u64 = @intFromEnum(action);
    if (modify_state) {
        code |= (1 << 8);
    }
    return code;
}
