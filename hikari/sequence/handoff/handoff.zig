//! Hikari Handoff Transaction

const boot = @import("shared").boot;
const common = @import("common");
const constants = @import("hikari").sequence.constants.memory;
const efi = @import("hikari").efi;
const errors = @import("hikari").sequence.errors;
const math = @import("utils").math;
const types = @import("hikari").sequence.types;

const BootParams = boot.types.params.BootParams;
const Handoff = types.handoff.Handoff;
const HandoffError = errors.handoff.HandoffError;
const layout = common.constants.memory.layout;
const memory = boot.constants.memory;
const sizes = common.constants.memory.sizes;
const status = efi.constants.status;

pub fn initialize(boot_services: *efi.services.boot.BootServices, physical_limit: u64) HandoffError!Handoff {
    if (physical_limit < sizes.PAGE_SIZE or physical_limit > layout.PHYSMAP_MAX_SIZE or
        (physical_limit & sizes.PAGE_MASK) != 0) return HandoffError.AllocationFailed;
    var state = Handoff{ .BootServices = boot_services, .PhysicalLimit = physical_limit };
    errdefer deinitialize(&state);
    state.StackPages = layout.KERNEL_STACK_PAGES;
    state.StackPhysical = try allocatePages(&state, state.StackPages);
    state.ParamsPages = math.integer.divideCeil(@sizeOf(BootParams), sizes.PAGE_SIZE);
    state.ParamsPhysical = try allocatePages(&state, state.ParamsPages);
    parameters(&state).* = BootParams.initialize();
    return state;
}

pub fn deinitialize(state: *Handoff) void {
    if (state.Exited) return;
    if (state.MapPhysical != 0) _ = state.BootServices.FreePages(state.MapPhysical, state.MapPages);
    if (state.ParamsPhysical != 0) _ = state.BootServices.FreePages(state.ParamsPhysical, state.ParamsPages);
    if (state.StackPhysical != 0) _ = state.BootServices.FreePages(state.StackPhysical, state.StackPages);
    state.MapPhysical = 0;
    state.ParamsPhysical = 0;
    state.StackPhysical = 0;
}

pub fn parameters(state: *const Handoff) *BootParams {
    return @ptrFromInt(state.ParamsPhysical);
}

pub fn parameterAlias(state: *const Handoff) u64 {
    return layout.PHYSMAP_BASE + state.ParamsPhysical;
}

pub fn stackTop(state: *const Handoff) u64 {
    return layout.PHYSMAP_BASE + state.StackPhysical + state.StackPages * sizes.PAGE_SIZE;
}

fn allocatePages(state: *const Handoff, pages: usize) HandoffError!u64 {
    if (pages == 0 or pages > state.PhysicalLimit / sizes.PAGE_SIZE) return HandoffError.AllocationFailed;
    var address: efi.types.base.PhysicalAddress = state.PhysicalLimit - 1;
    const allocation = state.BootServices.AllocatePages(.MaxAddress, .LoaderData, pages, &address);
    if (efi.types.base.isError(allocation)) return HandoffError.AllocationFailed;
    if (address == 0 or (address & sizes.PAGE_MASK) != 0 or address > state.PhysicalLimit - pages * sizes.PAGE_SIZE) {
        _ = state.BootServices.FreePages(address, pages);
        return HandoffError.AllocationFailed;
    }
    return address;
}

fn growMap(state: *Handoff, required: usize, descriptor_size: usize) HandoffError!void {
    const stride = @max(descriptor_size, @sizeOf(efi.types.memory.MemoryDescriptor));
    if (stride > memory.MAX_DESCRIPTOR_SIZE or required == 0) return HandoffError.InvalidMemoryMap;
    const extra = constants.MEMORY_MAP_EXTRA_DESCRIPTORS * stride;
    if (required > memory.MAX_MAP_BYTES - extra) return HandoffError.InvalidMemoryMap;
    const pages: usize = math.integer.divideCeil(required + extra, sizes.PAGE_SIZE);
    const address = try allocatePages(state, pages);
    if (state.MapPhysical != 0) {
        const release = state.BootServices.FreePages(state.MapPhysical, state.MapPages);
        if (efi.types.base.isError(release)) {
            _ = state.BootServices.FreePages(address, pages);
            return HandoffError.AllocationFailed;
        }
    }
    state.MapPhysical = address;
    state.MapPages = pages;
}

pub fn exit(state: *Handoff, image_handle: efi.types.base.Handle) HandoffError!void {
    var attempt: usize = 0;
    while (attempt < constants.EXIT_BOOT_SERVICES_ATTEMPTS) : (attempt += 1) {
        var size: usize = state.MapPages * sizes.PAGE_SIZE;
        var key: usize = 0;
        var descriptor_size: usize = 0;
        var descriptor_version: u32 = 0;
        var unused_descriptor: efi.types.memory.MemoryDescriptor = undefined;
        const descriptors: [*]efi.types.memory.MemoryDescriptor = if (state.MapPhysical == 0)
            @ptrCast(&unused_descriptor)
        else
            @ptrFromInt(state.MapPhysical);
        const result = state.BootServices.GetMemoryMap(&size, descriptors, &key, &descriptor_size, &descriptor_version);
        if (result == status.BUFFER_TOO_SMALL) {
            try growMap(state, size, descriptor_size);
            continue;
        }
        if (efi.types.base.isError(result) or state.MapPhysical == 0 or size == 0 or
            size > state.MapPages * sizes.PAGE_SIZE or descriptor_size < @sizeOf(efi.types.memory.MemoryDescriptor) or
            descriptor_size > memory.MAX_DESCRIPTOR_SIZE or descriptor_size % @alignOf(efi.types.memory.MemoryDescriptor) != 0 or
            size % descriptor_size != 0 or descriptor_version != memory.DESCRIPTOR_VERSION or size / descriptor_size > memory.MAX_REGIONS)
        {
            return HandoffError.InvalidMemoryMap;
        }
        parameters(state).MemoryMap = .{
            .Entries = state.MapPhysical,
            .EntryCount = @intCast(size / descriptor_size),
            .EntrySize = @intCast(descriptor_size),
            .DescriptorVersion = descriptor_version,
            .Reserved = 0,
        };
        state.ExitAttempted = true;
        const exit_status = state.BootServices.ExitBootServices(image_handle, key);
        if (exit_status == status.SUCCESS) {
            state.Exited = true;
            return;
        }
        if (exit_status != status.INVALID_PARAMETER) return HandoffError.ExitFailed;
    }
    return HandoffError.ExitFailed;
}
