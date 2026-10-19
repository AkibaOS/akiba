//! Bounded Loading Page Writes

const kata = @import("mirai").kata;
const transfer = @import("mirai").user.copy.transfer;
const usererrors = @import("mirai").user.errors.memory;

const Kata = kata.types.kata.Kata;
const UserError = usererrors.UserError;

pub fn load(owner: *Kata, virtual_address: u64, bytes: []const u8) UserError!void {
    return transfer.write(owner, virtual_address, bytes);
}
