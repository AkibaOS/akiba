//! One Way Owned User Page Finalization

const access = @import("mirai").user.state.access;
const checks = @import("mirai").user.state.checks;
const common = @import("common");
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const ledger = @import("mirai").user.state.ledger;
const types = @import("mirai").user.types;
const usererrors = @import("mirai").user.errors.memory;

const sizes = common.constants.memory.sizes;
const Kata = kata.types.kata.Kata;
const Protection = types.protection.Protection;
const Stage = types.stage.Stage;
const UserError = usererrors.UserError;

pub fn finalize(owner: *Kata, virtual_address: u64, protection: Protection) UserError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!checks.isValidOwner(owner) or owner.State == .Dead) return UserError.InvalidOwner;
    if ((virtual_address & sizes.PAGE_MASK) != 0) return UserError.AddressNotAligned;
    const record = ledger.find(owner, virtual_address) orelse return UserError.NotOwned;
    if (record.Stage != .Loading) return UserError.SealedPage;
    try access.validate(record, false);
    const stage: Stage = switch (protection) {
        .ReadOnly => .ReadOnly,
        .ReadWrite => .Writable,
        .ReadExecute => .Executable,
    };
    if (stage == .Writable) {
        record.Stage = stage;
        return;
    }
    const alias = try kagami.tables.physmap.prepare(owner, virtual_address);
    alias.Writable = false;
    cpu.control.flushAllTLB();
    record.Stage = stage;
    kagami.protect.protect(owner.AddressSpace.?, virtual_address, access.permissions(stage)) catch |failure| {
        record.Stage = .Loading;
        alias.Writable = true;
        cpu.control.flushAllTLB();
        return failure;
    };
}
