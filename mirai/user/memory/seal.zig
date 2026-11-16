//! Owned User Text Finalization

const finalization = @import("mirai").user.memory.finalize;
const kata = @import("mirai").kata;
const usererrors = @import("mirai").user.errors.memory;

const Kata = kata.types.kata.Kata;
const UserError = usererrors.UserError;

pub fn seal(owner: *Kata, virtual_address: u64) UserError!void {
    return finalization.finalize(owner, virtual_address, .ReadExecute);
}
