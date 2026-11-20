//! Hikari Handoff Transaction

const std = @import("std");

const boot = @import("shared").boot;
const common = @import("common");
const constants = @import("hikari").sequence.constants.memory;
const efi = @import("hikari").efi;
const errors = @import("hikari").sequence.errors;
const math = @import("utils").math;
const types = @import("hikari").sequence.types;

const Allocation = efi.types.pages.claims.Allocation;
const BootParams = boot.types.params.BootParams;
const Handoff = types.handoff.transfer.Handoff;
const HandoffError = errors.handoff.transfer.HandoffError;
const layout = common.constants.memory.layout;
const memory = boot.constants.memory;
const sizes = common.constants.memory.sizes;
const status = efi.constants.status.codes;

pub fn initialize(state: *Handoff) HandoffError!void {
    if (state.Closing or state.UntrustedAllocation or state.Exited or state.ExitAttempted or state.Stack != null or state.Parameters != null or
        state.Map != null or state.Replacement != null) return HandoffError.InvalidState;
    if (state.PhysicalLimit < sizes.PAGE_SIZE or state.PhysicalLimit > layout.PHYSMAP_MAX_SIZE or
        state.PhysicalLimit & sizes.PAGE_MASK != 0) return HandoffError.AllocationFailed;
    try allocate(state, &state.Stack, layout.KERNEL_STACK_PAGES);
    try allocate(state, &state.Parameters, math.integer.divideCeil(@sizeOf(BootParams), sizes.PAGE_SIZE));
    parameters(state).* = BootParams.initialize();
}

pub fn deinitialize(state: *Handoff) bool {
    if (state.ExitAttempted or state.Exited) return false;
    state.Closing = true;
    var released = true;
    if (!efi.pages.release(state.BootServices, &state.Replacement)) released = false;
    if (!efi.pages.release(state.BootServices, &state.Map)) released = false;
    if (!efi.pages.release(state.BootServices, &state.Parameters)) released = false;
    if (!efi.pages.release(state.BootServices, &state.Stack)) released = false;
    return released and !state.UntrustedAllocation;
}

pub fn parameters(state: *const Handoff) *BootParams {
    return @ptrFromInt(state.Parameters.?.Physical);
}

pub fn parameterAlias(state: *const Handoff) u64 {
    return layout.PHYSMAP_BASE + state.Parameters.?.Physical;
}

pub fn stackTop(state: *const Handoff) u64 {
    const stack = state.Stack.?;
    return layout.PHYSMAP_BASE + stack.Physical + stack.Pages * sizes.PAGE_SIZE;
}

fn allocate(state: *Handoff, owner: *?Allocation, pages: usize) HandoffError!void {
    const acquired = efi.pages.acquire(state.BootServices, null, state.PhysicalLimit, pages, owner);
    if (acquired == .Untrusted) state.UntrustedAllocation = true;
    if (acquired != .Acquired or owner.*.?.Physical == 0) return HandoffError.AllocationFailed;
}

fn growMap(state: *Handoff, required: usize, descriptor_size: usize) HandoffError!void {
    const stride = @max(descriptor_size, @sizeOf(efi.types.memory.MemoryDescriptor));
    if (stride > std.math.maxInt(u32) or required == 0) return HandoffError.InvalidMemoryMap;
    const extra = constants.MEMORY_MAP_EXTRA_DESCRIPTORS * stride;
    if (extra > state.PhysicalLimit or required > state.PhysicalLimit - extra) return HandoffError.InvalidMemoryMap;
    const bytes = required + extra;
    const pages = math.integer.divideCeil(bytes, sizes.PAGE_SIZE);
    try allocate(state, &state.Replacement, pages);
    if (!efi.pages.release(state.BootServices, &state.Map)) {
        _ = efi.pages.release(state.BootServices, &state.Replacement);
        return HandoffError.ReleaseFailed;
    }
    state.Map = state.Replacement;
    state.Replacement = null;
}

pub fn exit(state: *Handoff, image_handle: efi.types.base.Handle) HandoffError!void {
    if (state.Closing or state.UntrustedAllocation or state.ExitAttempted or state.Exited or state.Replacement != null or
        state.Stack == null or state.Stack.?.Physical == 0 or
        state.Parameters == null or state.Parameters.?.Physical == 0) return HandoffError.InvalidState;
    var attempt: usize = 0;
    while (attempt < constants.EXIT_BOOT_SERVICES_ATTEMPTS) : (attempt += 1) {
        const capacity = if (state.Map) |map| map.Pages * sizes.PAGE_SIZE else 0;
        var size = capacity;
        var key: usize = 0;
        var descriptor_size: usize = 0;
        var descriptor_version: u32 = 0;
        var unused_descriptor: efi.types.memory.MemoryDescriptor = undefined;
        const descriptors: [*]efi.types.memory.MemoryDescriptor = if (state.Map) |map|
            @ptrFromInt(map.Physical)
        else
            @ptrCast(&unused_descriptor);
        const result = state.BootServices.GetMemoryMap(&size, descriptors, &key, &descriptor_size, &descriptor_version);
        if (result == status.BUFFER_TOO_SMALL) {
            try growMap(state, size, descriptor_size);
            continue;
        }
        if (result != status.SUCCESS or state.Map == null or size == 0 or
            size > capacity or descriptor_size < @sizeOf(efi.types.memory.MemoryDescriptor) or
            descriptor_size > std.math.maxInt(u32) or descriptor_size % @alignOf(efi.types.memory.MemoryDescriptor) != 0 or
            size % descriptor_size != 0 or descriptor_version != memory.DESCRIPTOR_VERSION or size / descriptor_size > std.math.maxInt(u32))
        {
            return HandoffError.InvalidMemoryMap;
        }
        const map = state.Map.?;
        parameters(state).MemoryMap = .{
            .Entries = map.Physical,
            .EntryCount = @intCast(size / descriptor_size),
            .EntrySize = @intCast(descriptor_size),
            .DescriptorVersion = descriptor_version,
            .Reserved = 0,
        };
        const ownership = &parameters(state).Retirement;
        ownership.MapPages = map.Pages;
        if (ownership.LedgerPhysical != 0) {
            const ledger: *boot.types.retirement.Ledger = @ptrFromInt(ownership.LedgerPhysical);
            ledger.MapPhysical = map.Physical;
            ledger.MapPages = map.Pages;
        }
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
