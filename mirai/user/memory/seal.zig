//! Strict Owned User Text Sealing

const checks = @import("mirai").user.state.checks;
const common = @import("common");
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const ledger = @import("mirai").user.state.ledger;
const usererrors = @import("mirai").user.errors.memory;

const protection = kagami.constants.protection;
const sizes = common.constants.memory.sizes;
const Kata = kata.types.kata.Kata;
const UserError = usererrors.UserError;

pub fn seal(owner: *Kata, virtual_address: u64) UserError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!checks.isValidOwner(owner)) return UserError.InvalidOwner;
    if ((virtual_address & sizes.PAGE_MASK) != 0) return UserError.AddressNotAligned;
    const record = ledger.find(owner, virtual_address) orelse return UserError.NotOwned;
    if (record.Stage != .Loading) return UserError.SealedPage;
    const resolved = checks.lookupOwned(record) orelse return UserError.InvalidOwnedMapping;
    if (!resolved.Writable or resolved.Executable) return UserError.InvalidOwnedMapping;
    const alias = try kagami.tables.physmap.prepare(owner, virtual_address);
    alias.Writable = false;
    cpu.control.flushAllTLB();
    record.Stage = .Sealed;
    kagami.protect.protect(owner.AddressSpace, virtual_address, protection.READ | protection.EXECUTE | protection.USER) catch |failure| {
        record.Stage = .Loading;
        alias.Writable = true;
        cpu.control.flushAllTLB();
        return failure;
    };
}
