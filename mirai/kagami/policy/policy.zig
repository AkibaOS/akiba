//! Runtime Mapping Ownership And Alias Policy

const common = @import("common");
const constants = @import("mirai").kagami.constants.protection;
const create = @import("mirai").kagami.create;
const stacklimits = @import("mirai").memory.constants.stack.limits;
const state = @import("mirai").kagami.state;
const types = @import("mirai").kagami.types;
const walk = @import("mirai").kagami.tables.walk;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const MappingError = common.errors.memory.mapping.MappingError;
const Kagami = types.kagami.Kagami;

pub fn canMutate(kagami: *const Kagami, virtual_address: u64) MappingError!void {
    if ((virtual_address & sizes.PAGE_MASK) != 0) return MappingError.AddressNotAligned;
    if (!walk.isCanonical(virtual_address)) return MappingError.InvalidAddress;
    if (!state.hasOwnedKernel() or !walk.isValidTable(kagami.PML4Physical)) return MappingError.PermissionDenied;
    switch (kagami.Ownership) {
        .Kernel => {
            if (kagami != state.getKernelKagami() or virtual_address <= layout.USER_SPACE_END) return MappingError.PermissionDenied;
        },
        .User => {
            if (!create.owns(kagami) or !kagami.SharesKernel or virtual_address > layout.USER_SPACE_END) return MappingError.PermissionDenied;
        },
        .Borrowed, .Shared => return MappingError.PermissionDenied,
    }
    const policy = state.getPolicy();
    if (contains(virtual_address, policy.PhysmapBase, policy.PhysmapSize) or
        contains(virtual_address, policy.Image.VirtualStart, policy.Image.VirtualEnd - policy.Image.VirtualStart + sizes.PAGE_SIZE) or
        (virtual_address >= policy.BootStackBase - sizes.PAGE_SIZE and virtual_address < policy.BootStackTop + sizes.PAGE_SIZE))
    {
        return MappingError.PermissionDenied;
    }
    if (contains(virtual_address, stacklimits.AREA_BASE, stacklimits.AREA_SIZE)) {
        const slot_offset = (virtual_address - stacklimits.AREA_BASE) % stacklimits.SLOT_SIZE;
        const body_start = stacklimits.GUARD_PAGES * sizes.PAGE_SIZE;
        if (slot_offset < body_start or slot_offset >= body_start + stacklimits.STACK_SIZE) return MappingError.PermissionDenied;
    }
}

pub fn validateMapping(kagami: *const Kagami, virtual_address: u64, physical_address: u64, protection: u8) MappingError!void {
    try canMutate(kagami, virtual_address);
    if ((physical_address & sizes.PAGE_MASK) != 0) return MappingError.AddressNotAligned;
    const policy = state.getPolicy();
    if (physical_address >= policy.PhysicalLimit or sizes.PAGE_SIZE > policy.PhysicalLimit - physical_address) return MappingError.InvalidAddress;
    if ((protection & constants.READ) == 0 or
        (protection & ~(constants.READ | constants.WRITE | constants.EXECUTE | constants.USER | constants.WIRED | constants.NOCACHE)) != 0) return MappingError.PermissionDenied;
    const writable = (protection & constants.WRITE) != 0;
    const executable = (protection & constants.EXECUTE) != 0;
    const user_accessible = (protection & constants.USER) != 0;
    if ((writable and executable) or (user_accessible and virtual_address > layout.USER_SPACE_END)) return MappingError.PermissionDenied;
    const text = policy.Image.Text;
    const rodata = policy.Image.Rodata;
    const text_alias = contains(physical_address, text.PhysicalStart, text.VirtualEnd - text.VirtualStart);
    const rodata_alias = contains(physical_address, rodata.PhysicalStart, rodata.VirtualEnd - rodata.VirtualStart);
    if ((writable and (text_alias or rodata_alias)) or (executable and !text_alias) or
        (user_accessible and contains(physical_address, policy.Image.PhysicalStart, policy.Image.PhysicalEnd - policy.Image.PhysicalStart)))
    {
        return MappingError.PermissionDenied;
    }
    const uncached = (protection & constants.NOCACHE) != 0;
    const framebuffer_alias = physical_address >= policy.FramebufferStart and physical_address < policy.FramebufferEnd;
    if (physical_address < policy.PhysmapSize and uncached != framebuffer_alias) return MappingError.PermissionDenied;
    if (framebuffer_alias and (executable or user_accessible)) return MappingError.PermissionDenied;
}

fn contains(value: u64, start: u64, length: u64) bool {
    return value >= start and value - start < length;
}
