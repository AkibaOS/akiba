//! Keyboard Challenge State

const challenge = @import("tests").phase.constants.input;

pub const Key = struct { Name: []const u8, Make: u8 };
pub const Keys = [challenge.CHALLENGE_TAPS + 1]Key;
pub const Action = enum { Waiting, Inject, Complete };
pub const State = enum { Ready, Send, Make, Break, Done };

pub const Challenge = struct {
    Keys: []const Key,
    Offset: usize = 0,
    Index: usize = 0,
    State: State = .Ready,
};
