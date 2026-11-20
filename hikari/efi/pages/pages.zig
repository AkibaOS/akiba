//! Checked EFI Page Acquisition And Release

const common = @import("common");
const efi = @import("hikari").efi;

const Acquisition = efi.types.pages.claims.Acquisition;
const Allocation = efi.types.pages.claims.Allocation;
const BootServices = efi.types.services.boot.BootServices;
const sizes = common.constants.memory.sizes;
const status = efi.constants.status.codes;

pub fn acquire(services: *BootServices, requested: ?u64, limit: u64, count: usize, owner: *?Allocation) Acquisition {
    if (owner.* != null or count == 0 or limit & sizes.PAGE_MASK != 0 or count > limit / sizes.PAGE_SIZE) return .Invalid;
    const last = limit - count * sizes.PAGE_SIZE;
    if (requested) |address| {
        if (address > last or address & sizes.PAGE_MASK != 0) return .Unavailable;
    }
    var physical = requested orelse limit - 1;
    const mode: efi.types.memory.AllocateType = if (requested != null) .Address else .MaxAddress;
    if (services.AllocatePages(mode, .LoaderData, count, &physical) != status.SUCCESS) return .Unavailable;
    if (physical & sizes.PAGE_MASK != 0 or physical > last or (requested != null and physical != requested.?)) return .Untrusted;
    owner.* = .{ .Physical = physical, .Pages = count };
    return .Acquired;
}

pub fn free(services: *BootServices, allocation: Allocation) bool {
    return services.FreePages(allocation.Physical, allocation.Pages) == status.SUCCESS;
}

pub fn release(services: *BootServices, owner: *?Allocation) bool {
    const allocation = owner.* orelse return true;
    if (!free(services, allocation)) return false;
    owner.* = null;
    return true;
}
