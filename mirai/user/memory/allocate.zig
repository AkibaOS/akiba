//! Fresh Owned User Page Allocation

const checks = @import("mirai").user.state.checks;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const ledger = @import("mirai").user.state.ledger;
const pmm = @import("mirai").pmm;
const usererrors = @import("mirai").user.errors.memory;

const layout = common.constants.memory.layout;
const protection = kagami.constants.protection;
const sizes = common.constants.memory.sizes;
const Kata = kata.types.kata.Kata;
const UserError = usererrors.UserError;

pub fn allocate(owner: *Kata, virtual_address: u64) UserError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!checks.isValidOwner(owner)) return UserError.InvalidOwner;
    if ((virtual_address & sizes.PAGE_MASK) != 0) return UserError.AddressNotAligned;
    if (!checks.isValidRange(virtual_address, sizes.PAGE_SIZE)) return UserError.InvalidUserRange;
    if (ledger.find(owner, virtual_address) != null) return UserError.AlreadyOwned;
    if (!ledger.hasCapacity()) return UserError.OwnershipCapacity;
    if (kagami.tables.walk.lookup(owner.AddressSpace.PML4Physical, virtual_address) != null) return UserError.AlreadyMapped;
    const previous_search = pmm.state.getState().SearchStart;
    errdefer pmm.state.getState().SearchStart = previous_search;
    const physical_address = try pmm.allocate.single.allocatePage();
    errdefer pmm.free.single.freePage(physical_address);
    if (!checks.isPayloadPhysical(physical_address)) return UserError.InvalidPhysmap;
    const record = try ledger.register(owner, virtual_address, physical_address);
    errdefer ledger.unregister(record);
    const alias = checks.lookupAlias(record) orelse return UserError.InvalidPhysmap;
    if (!alias.Writable or !alias.Entry.Writable) return UserError.InvalidPhysmap;
    const destination: [*]u8 = @ptrFromInt(layout.PHYSMAP_BASE + physical_address);
    @memset(destination[0..sizes.PAGE_SIZE], 0);
    try kagami.enter.enter(owner.AddressSpace, virtual_address, physical_address, protection.READ | protection.WRITE | protection.USER);
}
