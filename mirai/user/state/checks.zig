//! Owned User Address And Alias Checks

const bits = @import("utils").bits;
const common = @import("common");
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const ledger = @import("mirai").user.state.ledger;
const pmm = @import("mirai").pmm;
const types = @import("mirai").user.types;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const Kata = kata.types.kata.Kata;
const Lookup = kagami.types.lookup.Lookup;
const Record = types.record.Record;

pub fn isValidOwner(owner: *const Kata) bool {
    if (!kata.state.owns(owner)) return false;
    return !owner.Permanent and kagami.create.owns(owner.AddressSpace) and
        owner.AddressSpace.SharesKernel and owner.AddressSpace.ExecutionOwners == 1;
}

pub fn isValidRange(virtual_address: u64, length: usize) bool {
    if (virtual_address == 0 or virtual_address > layout.USER_SPACE_END) return false;
    if (length == 0) return true;
    return length - 1 <= layout.USER_SPACE_END - virtual_address;
}

pub fn isPayloadPhysical(physical_address: u64) bool {
    if (!pmm.state.isInitialized() or physical_address == 0 or (physical_address & sizes.PAGE_MASK) != 0) return false;
    const policy = kagami.state.getPolicy();
    const managed_end = pmm.state.getState().TotalPages * sizes.PAGE_SIZE;
    if (physical_address < pmm.constants.limits.KERNEL_RESERVED_PAGES * sizes.PAGE_SIZE or
        physical_address >= managed_end or physical_address >= policy.PhysmapSize or
        sizes.PAGE_SIZE > policy.PhysmapSize - physical_address) return false;
    if (!bits.operations.testBit(pmm.state.getState().Bitmap, physical_address / sizes.PAGE_SIZE)) return false;
    if ((physical_address >= policy.Image.PhysicalStart and physical_address < policy.Image.PhysicalEnd) or
        (physical_address >= policy.FramebufferStart and physical_address < policy.FramebufferEnd)) return false;
    const bitmap_address = @intFromPtr(pmm.state.getState().Bitmap.ptr);
    if (bitmap_address < layout.PHYSMAP_BASE) return false;
    const bitmap_start = bitmap_address - layout.PHYSMAP_BASE;
    const bitmap_size = (pmm.state.getState().BitmapSize + sizes.PAGE_MASK) & ~sizes.PAGE_MASK;
    return physical_address < bitmap_start or physical_address - bitmap_start >= bitmap_size;
}

pub fn lookupOwned(record: *const Record) ?Lookup {
    if (!isValidOwner(record.Owner) or ledger.find(record.Owner, record.VA) != record or
        !isValidRange(record.VA, sizes.PAGE_SIZE) or (record.VA & sizes.PAGE_MASK) != 0 or
        !isPayloadPhysical(record.PA)) return null;
    const resolved = kagami.tables.walk.lookup(record.Owner.AddressSpace.PML4Physical, record.VA) orelse return null;
    if (resolved.PageSize != sizes.PAGE_SIZE or resolved.PhysicalAddress != record.PA or
        !resolved.UserAccessible or resolved.Entry.Global or resolved.Entry.CacheDisabled or resolved.Entry.WriteThrough or
        resolved.Entry.HugePage) return null;
    const leaf = kagami.tables.walk.walkToOwnedEntry(record.Owner.AddressSpace.PML4Physical, record.VA) orelse return null;
    return if (leaf == resolved.Entry) resolved else null;
}

pub fn lookupAlias(record: *const Record) ?Lookup {
    if (!isValidOwner(record.Owner) or ledger.find(record.Owner, record.VA) != record or
        !isPayloadPhysical(record.PA) or !kagami.state.hasOwnedKernel()) return null;
    const policy = kagami.state.getPolicy();
    if (policy.PhysmapBase != layout.PHYSMAP_BASE) return null;
    const resolved = kagami.tables.walk.lookup(kagami.state.getKernelKagami().PML4Physical, policy.PhysmapBase + record.PA) orelse return null;
    if (resolved.PhysicalAddress != record.PA or resolved.UserAccessible or resolved.Entry.UserAccessible or
        resolved.Executable or !resolved.Entry.NoExecute or resolved.Entry.CacheDisabled or resolved.Entry.WriteThrough) return null;
    const pat = if (resolved.PageSize == sizes.PAGE_SIZE) resolved.Entry.HugePage else (resolved.Entry.getPhysicalAddress() & sizes.PAGE_SIZE) != 0;
    return if (!pat) resolved else null;
}
