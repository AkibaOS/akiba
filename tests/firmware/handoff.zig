//! Firmware Backed Handoff Client Regressions

const base = @import("hikari").efi.types.base;
const codes = @import("hikari").efi.constants.status;
const convention = @import("hikari").efi.constants.convention;
const errors = @import("hikari").sequence.errors.handoff;
const handoff = @import("hikari").sequence.handoff;
const inputs = @import("tests").constants.firmware;
const labels = @import("tests").strings.firmware;
const memory = @import("hikari").efi.types.memory;
const output = @import("tests").firmware.run;
const services = @import("hikari").efi.types.services;
const status = @import("hikari").efi.status;
const types = @import("tests").types.firmware;

var fixture: types.Fixture = undefined;
var active: bool = false;

pub fn run(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    defer if (!cleanup()) output.fail(labels.CLEANUP_FAILED);
    try initializeRollback(real, image_handle);
    try initializeRelease(real, image_handle);
    try mapGrowth(real, image_handle);
    const bad_stride = try metadataRejected(real, image_handle, &inputs.BAD_STRIDE_MAPS);
    const bad_version = try metadataRejected(real, image_handle, &inputs.BAD_VERSION_MAPS);
    output.require(bad_stride and bad_version, labels.MAP_METADATA);
    try staleRetry(real, image_handle);
    try retryBound(real, image_handle);
    try growthRollback(real, image_handle);
    try mapCapacity(real, image_handle, inputs.MANY_MAP_ENTRIES, inputs.DESCRIPTOR_BYTES, labels.MAP_COUNT);
    try mapCapacity(real, image_handle, inputs.MAP_ENTRIES, inputs.EXTENDED_DESCRIPTOR_BYTES, labels.MAP_STRIDE);
    try mapCapacity(real, image_handle, inputs.LARGE_MAP_ENTRIES, inputs.DESCRIPTOR_BYTES, labels.MAP_BYTES);
}

pub fn cleanup() bool {
    if (!active) return true;
    var released = true;
    for (&fixture.Ledger) |*allocation| {
        if (allocation.Address == 0) continue;
        const result = fixture.Real.FreePages(allocation.Address, allocation.Pages);
        if (status.isError(result)) {
            released = false;
        } else {
            allocation.* = .{};
        }
    }
    if (released) active = false;
    return released;
}

fn initializeRollback(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &.{}, &.{});
    fixture.FailAllocateCall = 2;
    var rejected = false;
    if (handoff.initialize(&wrapped, inputs.PHYSICAL_LIMIT)) |allocated| {
        var unexpected = allocated;
        handoff.deinitialize(&unexpected);
    } else |failure| {
        rejected = failure == errors.HandoffError.AllocationFailed;
    }
    finish(rejected and fixture.AllocateCalls == 2 and fixture.CreatedCount == 1 and fixture.FreeCalls == 1 and
        fixture.Created[0].Pages == inputs.STACK_PAGES and fixture.Freed[0].Address == fixture.Created[0].Address and
        fixture.Freed[0].Pages == inputs.STACK_PAGES and ownedCount() == 0, labels.INITIALIZE_ROLLBACK);
}

fn initializeRelease(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &.{}, &.{});
    var state = try handoff.initialize(&wrapped, inputs.PHYSICAL_LIMIT);
    const stack_address = state.StackPhysical;
    const params_address = state.ParamsPhysical;
    const initialized = handoff.parameters(&state).isValid() and state.StackPages == inputs.STACK_PAGES and
        state.ParamsPages == inputs.PARAMS_PAGES and fixture.CreatedCount == 2 and ownedCount() == 2;
    handoff.deinitialize(&state);
    handoff.deinitialize(&state);
    finish(initialized and fixture.FreeCalls == 2 and fixture.Freed[0].Address == params_address and
        fixture.Freed[1].Address == stack_address and state.StackPhysical == 0 and state.ParamsPhysical == 0 and
        state.MapPhysical == 0 and ownedCount() == 0, labels.INITIALIZE_RELEASE);
}

fn mapGrowth(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &inputs.GROWTH_MAPS, &inputs.SUCCESS_EXIT);
    var state = try handoff.initialize(&wrapped, inputs.PHYSICAL_LIMIT);
    try handoff.exit(&state, image_handle);
    const published = handoff.parameters(&state).MemoryMap;
    const grown = state.Exited and state.ExitAttempted and state.MapPages == 2 and fixture.MapCalls == 3 and
        fixture.ExitCalls == 1 and fixture.ExitKeys[0] == inputs.FIRST_KEY and fixture.AllocateCalls == 4 and
        fixture.FreeCalls == 1 and fixture.Freed[0].Address == fixture.Created[2].Address and
        state.MapPhysical == fixture.Created[3].Address and fixture.MapCapacities[0] == 0 and
        fixture.MapCapacities[1] == inputs.PAGE_BYTES and fixture.MapCapacities[2] == 2 * inputs.PAGE_BYTES and
        published.Entries == state.MapPhysical and published.EntryCount == inputs.MAP_ENTRIES and
        published.EntrySize == inputs.DESCRIPTOR_BYTES and published.DescriptorVersion == inputs.DESCRIPTOR_VERSION and
        published.Reserved == 0;
    const stack_address = state.StackPhysical;
    const params_address = state.ParamsPhysical;
    const map_address = state.MapPhysical;
    const free_calls = fixture.FreeCalls;
    handoff.deinitialize(&state);
    const frozen = state.Exited and state.ExitAttempted and state.StackPhysical == stack_address and
        state.ParamsPhysical == params_address and state.MapPhysical == map_address and
        fixture.FreeCalls == free_calls and ownedCount() == 3;
    const matched = !fixture.ScriptMismatch;
    const released = cleanup();
    output.require(grown and matched and released, labels.MAP_GROWTH);
    output.require(frozen and matched and released, labels.EXITED_RELEASE);
}

fn mapCapacity(real: *services.boot.BootServices, image_handle: base.Handle, count: usize, stride: usize, comptime label: []const u8) !void {
    const size = count * stride;
    const script = [_]types.MapReply{
        .{ .Status = codes.BUFFER_TOO_SMALL, .Size = size, .DescriptorSize = stride },
        .{ .Status = codes.SUCCESS, .Size = size, .DescriptorSize = stride },
    };
    var wrapped = try begin(real, image_handle, &script, &inputs.SUCCESS_EXIT);
    var state = try handoff.initialize(&wrapped, inputs.PHYSICAL_LIMIT);
    try handoff.exit(&state, image_handle);
    const published = handoff.parameters(&state).MemoryMap;
    finish(state.Exited and fixture.MapCalls == 2 and fixture.ExitCalls == 1 and published.Entries == state.MapPhysical and
        published.EntryCount == count and published.EntrySize == stride and state.MapPages * inputs.PAGE_BYTES >= size and
        !fixture.ScriptMismatch, label);
}

fn metadataRejected(real: *services.boot.BootServices, image_handle: base.Handle, script: []const types.MapReply) !bool {
    var wrapped = try begin(real, image_handle, script, &.{});
    var state = try handoff.initialize(&wrapped, inputs.PHYSICAL_LIMIT);
    var rejected = false;
    handoff.exit(&state, image_handle) catch |failure| {
        rejected = failure == errors.HandoffError.InvalidMemoryMap;
    };
    const untouched = !state.ExitAttempted and !state.Exited and handoff.parameters(&state).MemoryMap.EntryCount == 0;
    handoff.deinitialize(&state);
    const matched = rejected and untouched and fixture.MapCalls == 2 and fixture.ExitCalls == 0 and
        fixture.FreeCalls == 3 and ownedCount() == 0 and !fixture.ScriptMismatch;
    const released = cleanup();
    return matched and released;
}

fn staleRetry(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &inputs.STALE_MAPS, &inputs.STALE_EXITS);
    var state = try handoff.initialize(&wrapped, inputs.PHYSICAL_LIMIT);
    try handoff.exit(&state, image_handle);
    finish(state.Exited and state.ExitAttempted and fixture.MapCalls == 3 and fixture.ExitCalls == 2 and
        fixture.ExitKeys[0] == inputs.FIRST_KEY and fixture.ExitKeys[1] == inputs.SECOND_KEY and
        fixture.AllocateCalls == 3 and fixture.FreeCalls == 0 and fixture.MapCapacities[1] == inputs.PAGE_BYTES and
        fixture.MapCapacities[2] == inputs.PAGE_BYTES, labels.STALE_RETRY);
}

fn retryBound(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &inputs.BOUNDED_MAPS, &inputs.BOUNDED_EXITS);
    var state = try handoff.initialize(&wrapped, inputs.PHYSICAL_LIMIT);
    var rejected = false;
    handoff.exit(&state, image_handle) catch |failure| {
        rejected = failure == errors.HandoffError.ExitFailed;
    };
    const bounded = rejected and state.ExitAttempted and !state.Exited and fixture.MapCalls == inputs.RETRY_MAP_CALLS and
        fixture.ExitCalls == inputs.RETRY_EXIT_CALLS and fixture.ExitKeys[0] == inputs.FIRST_KEY and
        fixture.ExitKeys[inputs.RETRY_EXIT_CALLS - 1] == inputs.LAST_KEY and fixture.AllocateCalls == 3;
    handoff.deinitialize(&state);
    finish(bounded and fixture.FreeCalls == 3 and state.MapPhysical == 0 and state.ParamsPhysical == 0 and
        state.StackPhysical == 0 and ownedCount() == 0, labels.RETRY_BOUND);
}

fn growthRollback(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &inputs.ROLLBACK_MAPS, &.{});
    fixture.FailFreeCall = 1;
    var state = try handoff.initialize(&wrapped, inputs.PHYSICAL_LIMIT);
    var rejected = false;
    handoff.exit(&state, image_handle) catch |failure| {
        rejected = failure == errors.HandoffError.AllocationFailed;
    };
    const rolled_back = rejected and !state.ExitAttempted and !state.Exited and fixture.MapCalls == 2 and
        fixture.ExitCalls == 0 and fixture.CreatedCount == 4 and fixture.FreeCalls == 2 and state.MapPages == 1 and
        state.MapPhysical == fixture.Created[2].Address and fixture.Freed[0].Address == fixture.Created[2].Address and
        fixture.Freed[1].Address == fixture.Created[3].Address and fixture.Freed[1].Pages == 2 and ownedCount() == 3;
    handoff.deinitialize(&state);
    finish(rolled_back and fixture.FreeCalls == 5 and fixture.Freed[2].Address == fixture.Created[2].Address and
        state.MapPhysical == 0 and state.ParamsPhysical == 0 and state.StackPhysical == 0 and ownedCount() == 0, labels.GROWTH_ROLLBACK);
}

fn begin(real: *services.boot.BootServices, image_handle: base.Handle, maps: []const types.MapReply, exits: []const base.Status) !services.boot.BootServices {
    if (!cleanup()) return errors.HandoffError.AllocationFailed;
    fixture = .{ .Real = real, .ImageHandle = image_handle, .MapScript = maps, .ExitScript = exits };
    active = true;
    var wrapped = real.*;
    wrapped.AllocatePages = allocatePages;
    wrapped.FreePages = freePages;
    wrapped.GetMemoryMap = getMemoryMap;
    wrapped.ExitBootServices = exitBootServices;
    return wrapped;
}

fn finish(condition: bool, comptime name: []const u8) void {
    const matched = !fixture.ScriptMismatch;
    const released = cleanup();
    output.require(condition and matched and released, name);
}

fn ownedCount() usize {
    var count: usize = 0;
    for (fixture.Ledger) |allocation| {
        if (allocation.Address != 0) count += 1;
    }
    return count;
}

fn allocatePages(allocate_type: memory.AllocateType, memory_type: memory.MemoryType, pages: usize, address: *base.PhysicalAddress) callconv(convention.CALLING_CONVENTION) base.Status {
    fixture.AllocateCalls += 1;
    if (fixture.FailAllocateCall == fixture.AllocateCalls) return codes.OUT_OF_RESOURCES;
    if (allocate_type != .MaxAddress or memory_type != .LoaderData or fixture.CreatedCount == inputs.TRACE_CAPACITY) {
        fixture.ScriptMismatch = true;
        return codes.OUT_OF_RESOURCES;
    }
    var available: ?*types.PageAllocation = null;
    for (&fixture.Ledger) |*record| {
        if (record.Address == 0) {
            available = record;
            break;
        }
    }
    const allocation = available orelse {
        fixture.ScriptMismatch = true;
        return codes.OUT_OF_RESOURCES;
    };
    const result = fixture.Real.AllocatePages(allocate_type, memory_type, pages, address);
    if (!status.isError(result)) {
        allocation.* = .{ .Address = address.*, .Pages = pages };
        fixture.Created[fixture.CreatedCount] = allocation.*;
        fixture.CreatedCount += 1;
    }
    return result;
}

fn freePages(address: base.PhysicalAddress, pages: usize) callconv(convention.CALLING_CONVENTION) base.Status {
    if (fixture.FreeCalls == inputs.TRACE_CAPACITY) {
        fixture.ScriptMismatch = true;
        return codes.DEVICE_ERROR;
    }
    fixture.Freed[fixture.FreeCalls] = .{ .Address = address, .Pages = pages };
    fixture.FreeCalls += 1;
    if (fixture.FailFreeCall == fixture.FreeCalls) return codes.DEVICE_ERROR;
    for (&fixture.Ledger) |*allocation| {
        if (allocation.Address == address and allocation.Pages == pages) {
            const result = fixture.Real.FreePages(address, pages);
            if (!status.isError(result)) allocation.* = .{};
            return result;
        }
    }
    fixture.ScriptMismatch = true;
    return codes.DEVICE_ERROR;
}

fn getMemoryMap(size: *usize, descriptors: [*]memory.MemoryDescriptor, key: *usize, descriptor_size: *usize, descriptor_version: *u32) callconv(convention.CALLING_CONVENTION) base.Status {
    const call = fixture.MapCalls;
    fixture.MapCalls += 1;
    if (call >= fixture.MapScript.len or call >= inputs.SCRIPT_CAPACITY) {
        fixture.ScriptMismatch = true;
        return codes.DEVICE_ERROR;
    }
    const capacity = size.*;
    fixture.MapCapacities[call] = capacity;
    const reply = fixture.MapScript[call];
    size.* = reply.Size;
    key.* = reply.Key;
    descriptor_size.* = reply.DescriptorSize;
    descriptor_version.* = reply.DescriptorVersion;
    if (reply.Status == codes.SUCCESS and reply.Size == inputs.MAP_BYTES and
        reply.DescriptorSize == inputs.DESCRIPTOR_BYTES and reply.DescriptorVersion == inputs.DESCRIPTOR_VERSION)
    {
        if (capacity < reply.Size) {
            fixture.ScriptMismatch = true;
            return codes.DEVICE_ERROR;
        }
        const bytes: [*]u8 = @ptrCast(descriptors);
        @memset(bytes[0..reply.Size], 0);
        const first: *memory.MemoryDescriptor = @ptrCast(@alignCast(bytes));
        const second: *memory.MemoryDescriptor = @ptrCast(@alignCast(bytes + inputs.DESCRIPTOR_BYTES));
        first.* = .{
            .MemoryType = .LoaderData,
            .PhysicalStart = fixture.Created[0].Address,
            .VirtualStart = 0,
            .NumberOfPages = @intCast(fixture.Created[0].Pages),
            .Attribute = 0,
        };
        second.* = .{
            .MemoryType = .LoaderData,
            .PhysicalStart = fixture.Created[1].Address,
            .VirtualStart = 0,
            .NumberOfPages = @intCast(fixture.Created[1].Pages),
            .Attribute = 0,
        };
    }
    return reply.Status;
}

fn exitBootServices(image_handle: base.Handle, key: usize) callconv(convention.CALLING_CONVENTION) base.Status {
    const call = fixture.ExitCalls;
    fixture.ExitCalls += 1;
    if (call >= fixture.ExitScript.len or call >= inputs.SCRIPT_CAPACITY or image_handle != fixture.ImageHandle or
        fixture.MapCalls == 0 or fixture.MapCalls > fixture.MapScript.len or key != fixture.MapScript[fixture.MapCalls - 1].Key)
    {
        fixture.ScriptMismatch = true;
        return codes.DEVICE_ERROR;
    }
    fixture.ExitKeys[call] = key;
    return fixture.ExitScript[call];
}
