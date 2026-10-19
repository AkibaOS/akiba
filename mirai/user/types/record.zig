//! Owned User Page Record

const kata = @import("mirai").kata;
const stage = @import("mirai").user.types.stage;

const Kata = kata.types.kata.Kata;
const Stage = stage.Stage;

pub const Record = struct {
    Owner: *Kata,
    VA: u64,
    PA: u64,
    Stage: Stage = .Loading,
};
