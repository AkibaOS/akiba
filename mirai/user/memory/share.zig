//! Map An Existing Sealed User Frame Into A Born Kata

const access = @import("mirai").user.state.access;
const checks = @import("mirai").user.state.checks;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const ledger = @import("mirai").user.state.ledger;
const pmm = @import("mirai").pmm;

const Kata = @import("mirai").kata.types.kata.Kata;
const UserError = @import("mirai").user.errors.memory.UserError;

pub fn map(source: *const Kata, source_address: u64, receiver: *Kata, destination: u64) UserError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!checks.isValidOwner(source) or source.State == .Dead or !checks.isValidOwner(receiver)) return UserError.InvalidOwner;
    if (receiver.State != .Born) return UserError.OwnerInUse;
    const original = ledger.find(source, source_address) orelse return UserError.NotOwned;
    const frame = original.Backing;
    if (frame.Stage != .ReadOnly and frame.Stage != .Executable) return UserError.NotShareable;
    try access.validate(original, false);
    const search = pmm.state.getState().SearchStart;
    errdefer pmm.state.getState().SearchStart = search;
    const record = try ledger.registerShared(receiver, destination, frame);
    errdefer ledger.unregister(record);
    try kagami.enter.enter(record.Root, destination, frame.PA, access.permissions(frame.Stage));
}
