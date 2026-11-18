//! Firmware Backed Handoff Client Regressions

const abort = @import("hikari").sequence.cleanup;
const base = @import("hikari").efi.types.base;
const boot = @import("shared").boot;
const claimtypes = @import("hikari").sequence.types.cleanup;
const codes = @import("hikari").efi.constants.status;
const convention = @import("hikari").efi.constants.convention;
const efi = @import("hikari").efi;
const errors = @import("hikari").sequence.errors.handoff;
const handoff = @import("hikari").sequence.handoff;
const handofftypes = @import("hikari").sequence.types.handoff;
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
    const cleanup_retained = try cleanupRetry(real, image_handle);
    const both_maps_retained = try replacementRetry(real, image_handle);
    finish(cleanup_retained and both_maps_retained, labels.RELEASE_RETRY);
    try abortRetry(real, image_handle, false, labels.ABORT_RETRY);
    try abortRetry(real, image_handle, true, labels.ABORT_REFUSAL);
    try mapCapacity(real, image_handle, inputs.MANY_MAP_ENTRIES, inputs.DESCRIPTOR_BYTES, labels.MAP_COUNT);
    try mapCapacity(real, image_handle, inputs.MAP_ENTRIES, inputs.EXTENDED_DESCRIPTOR_BYTES, labels.MAP_STRIDE);
    try mapCapacity(real, image_handle, inputs.LARGE_MAP_ENTRIES, inputs.DESCRIPTOR_BYTES, labels.MAP_BYTES);
    try retrySeparateTables(real, image_handle);
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
    if (fixture.Source) |source| {
        if (fixture.Real.FreePool(source) == codes.SUCCESS) {
            fixture.Source = null;
        } else {
            released = false;
        }
    }
    if (released) active = false;
    return released;
}

fn initializeRollback(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &.{}, &.{});
    fixture.FailAllocateCall = 2;
    fixture.FailFreeCalls = &.{1};
    var state: handofftypes.Handoff = .{ .BootServices = &wrapped, .PhysicalLimit = inputs.PHYSICAL_LIMIT };
    const rejected = if (handoff.initialize(&state)) |_| false else |failure| failure == errors.HandoffError.AllocationFailed;
    const recorded = fixture.AllocateCalls == 2 and fixture.CreatedCount == 1 and fixture.FreeCalls == 0 and
        state.Stack != null and state.Stack.?.Physical == fixture.Created[0].Address and
        state.Stack.?.Pages == inputs.STACK_PAGES and state.Parameters == null and ownedCount() == 1;
    const initially_released = handoff.deinitialize(&state);
    const retained = state.Stack != null and fixture.FreeCalls == 1 and ownedCount() == 1;
    const released = handoff.deinitialize(&state);
    finish(rejected and recorded and !initially_released and retained and released and fixture.AllocateCalls == 2 and
        fixture.FreeCalls == 2 and fixture.Freed[0].Address == fixture.Created[0].Address and
        fixture.Freed[1].Address == fixture.Created[0].Address and fixture.Freed[1].Pages == inputs.STACK_PAGES and
        state.Stack == null and ownedCount() == 0, labels.INITIALIZE_ROLLBACK);
}

fn initializeRelease(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &.{}, &.{});
    var state = try initializedState(&wrapped);
    const stack_address = state.Stack.?.Physical;
    const params_address = state.Parameters.?.Physical;
    const initialized = handoff.parameters(&state).isValid() and state.Stack.?.Pages == inputs.STACK_PAGES and
        state.Parameters.?.Pages == inputs.PARAMS_PAGES and fixture.CreatedCount == 2 and ownedCount() == 2;
    const released = handoff.deinitialize(&state);
    const repeated = handoff.deinitialize(&state);
    finish(initialized and released and repeated and fixture.FreeCalls == 2 and fixture.Freed[0].Address == params_address and
        fixture.Freed[1].Address == stack_address and state.Stack == null and state.Parameters == null and
        state.Map == null and ownedCount() == 0, labels.INITIALIZE_RELEASE);
}

fn mapGrowth(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &inputs.GROWTH_MAPS, &inputs.SUCCESS_EXIT);
    var state = try initializedState(&wrapped);
    try handoff.exit(&state, image_handle);
    const published = handoff.parameters(&state).MemoryMap;
    const grown = state.Exited and state.ExitAttempted and state.Map.?.Pages == 2 and fixture.MapCalls == 3 and
        fixture.ExitCalls == 1 and fixture.ExitKeys[0] == inputs.FIRST_KEY and fixture.AllocateCalls == 4 and
        fixture.FreeCalls == 1 and fixture.Freed[0].Address == fixture.Created[2].Address and
        state.Map.?.Physical == fixture.Created[3].Address and fixture.MapCapacities[0] == 0 and
        fixture.MapCapacities[1] == inputs.PAGE_BYTES and fixture.MapCapacities[2] == 2 * inputs.PAGE_BYTES and
        published.Entries == state.Map.?.Physical and published.EntryCount == inputs.MAP_ENTRIES and
        published.EntrySize == inputs.DESCRIPTOR_BYTES and published.DescriptorVersion == inputs.DESCRIPTOR_VERSION and
        published.Reserved == 0 and handoff.parameters(&state).Retirement.MapPages == state.Map.?.Pages;
    const stack_address = state.Stack.?.Physical;
    const params_address = state.Parameters.?.Physical;
    const map_address = state.Map.?.Physical;
    const free_calls = fixture.FreeCalls;
    const refused = !handoff.deinitialize(&state);
    const frozen = refused and state.Exited and state.ExitAttempted and state.Stack.?.Physical == stack_address and
        state.Parameters.?.Physical == params_address and state.Map.?.Physical == map_address and
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
    var state = try initializedState(&wrapped);
    try handoff.exit(&state, image_handle);
    const published = handoff.parameters(&state).MemoryMap;
    finish(state.Exited and fixture.MapCalls == 2 and fixture.ExitCalls == 1 and published.Entries == state.Map.?.Physical and
        published.EntryCount == count and published.EntrySize == stride and state.Map.?.Pages * inputs.PAGE_BYTES >= size and
        !fixture.ScriptMismatch, label);
}

fn metadataRejected(real: *services.boot.BootServices, image_handle: base.Handle, script: []const types.MapReply) !bool {
    var wrapped = try begin(real, image_handle, script, &.{});
    var state = try initializedState(&wrapped);
    var rejected = false;
    handoff.exit(&state, image_handle) catch |failure| {
        rejected = failure == errors.HandoffError.InvalidMemoryMap;
    };
    const untouched = !state.ExitAttempted and !state.Exited and handoff.parameters(&state).MemoryMap.EntryCount == 0;
    const deinitialized = handoff.deinitialize(&state);
    const matched = rejected and untouched and deinitialized and fixture.MapCalls == 2 and fixture.ExitCalls == 0 and
        fixture.FreeCalls == 3 and ownedCount() == 0 and !fixture.ScriptMismatch;
    const released = cleanup();
    return matched and released;
}

fn staleRetry(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &inputs.STALE_MAPS, &inputs.STALE_EXITS);
    var state = try initializedState(&wrapped);
    var ledger: boot.types.retirement.Ledger = .{};
    fixture.PublishedParams = handoff.parameters(&state);
    handoff.parameters(&state).Retirement.LedgerPhysical = @intFromPtr(&ledger);
    try handoff.exit(&state, image_handle);
    finish(state.Exited and state.ExitAttempted and fixture.MapCalls == 4 and fixture.ExitCalls == 2 and
        fixture.ExitKeys[0] == inputs.FIRST_KEY and fixture.ExitKeys[1] == inputs.SECOND_KEY and
        fixture.AllocateCalls == 4 and fixture.FreeCalls == 1 and fixture.Freed[0].Address == fixture.Created[2].Address and
        fixture.MapCapacities[2] == inputs.PAGE_BYTES and fixture.MapCapacities[3] == 2 * inputs.PAGE_BYTES and
        state.Map != null and state.Map.?.Physical == fixture.Created[3].Address and ownedCount() == 3, labels.STALE_RETRY);
}

fn retryBound(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &inputs.BOUNDED_MAPS, &inputs.BOUNDED_EXITS);
    var state = try initializedState(&wrapped);
    var rejected = false;
    handoff.exit(&state, image_handle) catch |failure| {
        rejected = failure == errors.HandoffError.ExitFailed;
    };
    const bounded = rejected and state.ExitAttempted and !state.Exited and fixture.MapCalls == inputs.RETRY_MAP_CALLS and
        fixture.ExitCalls == inputs.RETRY_EXIT_CALLS and fixture.ExitKeys[0] == inputs.FIRST_KEY and
        fixture.ExitKeys[inputs.RETRY_EXIT_CALLS - 1] == inputs.LAST_KEY and fixture.AllocateCalls == 3;
    var claims: claimtypes.Claims = .{ .Paging = .{ .BootServices = &wrapped }, .Handoff = state };
    const refused = !handoff.deinitialize(&state);
    const abort_refused = !abort.finish(&claims) and !abort.releaseSource(&claims);
    const reentry_refused = if (handoff.exit(&state, image_handle)) |_| false else |failure| failure == error.InvalidState;
    finish(bounded and refused and abort_refused and reentry_refused and !claims.Paging.Closing and
        fixture.MapCalls == inputs.RETRY_MAP_CALLS and fixture.ExitCalls == inputs.RETRY_EXIT_CALLS and
        fixture.FreeCalls == 0 and state.Map != null and state.Parameters != null and
        state.Stack != null and ownedCount() == 3, labels.RETRY_BOUND);
}

fn growthRollback(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &inputs.ROLLBACK_MAPS, &.{});
    fixture.FailFreeCalls = &.{1};
    var state = try initializedState(&wrapped);
    var rejected = false;
    handoff.exit(&state, image_handle) catch |failure| {
        rejected = failure == errors.HandoffError.ReleaseFailed;
    };
    const rolled_back = rejected and !state.ExitAttempted and !state.Exited and fixture.MapCalls == 2 and
        fixture.ExitCalls == 0 and fixture.CreatedCount == 4 and fixture.FreeCalls == 2 and state.Map.?.Pages == 1 and
        state.Map.?.Physical == fixture.Created[2].Address and fixture.Freed[0].Address == fixture.Created[2].Address and
        fixture.Freed[1].Address == fixture.Created[3].Address and fixture.Freed[1].Pages == 2 and ownedCount() == 3;
    const released = handoff.deinitialize(&state);
    finish(rolled_back and released and state.Replacement == null and fixture.FreeCalls == 5 and fixture.Freed[2].Address == fixture.Created[2].Address and
        state.Map == null and state.Parameters == null and state.Stack == null and ownedCount() == 0, labels.GROWTH_ROLLBACK);
}

fn cleanupRetry(real: *services.boot.BootServices, image_handle: base.Handle) !bool {
    var wrapped = try begin(real, image_handle, &.{}, &.{});
    var state = try initializedState(&wrapped);
    const parameters_address = state.Parameters.?.Physical;
    fixture.FailFreeCalls = &.{1};
    const refused = !handoff.deinitialize(&state);
    const retained = refused and state.Parameters != null and state.Parameters.?.Physical == parameters_address and state.Stack == null and ownedCount() == 1;
    const released = handoff.deinitialize(&state);
    return retained and released and state.Parameters == null and fixture.FreeCalls == 3 and
        fixture.Freed[2].Address == parameters_address and ownedCount() == 0 and !fixture.ScriptMismatch;
}

fn replacementRetry(real: *services.boot.BootServices, image_handle: base.Handle) !bool {
    var wrapped = try begin(real, image_handle, &inputs.ROLLBACK_MAPS, &.{});
    fixture.FailFreeCalls = &.{ 1, 2 };
    var state = try initializedState(&wrapped);
    const rejected = if (handoff.exit(&state, image_handle)) |_| false else |failure| failure == error.ReleaseFailed;
    const reentry_refused = if (handoff.exit(&state, image_handle)) |_| false else |failure| failure == error.InvalidState;
    const intact = rejected and reentry_refused and !state.Exited and !state.ExitAttempted and fixture.ExitCalls == 0 and
        fixture.MapCalls == 2 and fixture.AllocateCalls == 4 and fixture.FreeCalls == 2 and ownedCount() == 4 and
        state.Map != null and state.Map.?.Physical == fixture.Created[2].Address and state.Map.?.Pages == 1 and
        state.Replacement != null and state.Replacement.?.Physical == fixture.Created[3].Address and state.Replacement.?.Pages == 2;
    const released = handoff.deinitialize(&state);
    return intact and released and state.Map == null and state.Replacement == null and fixture.FreeCalls == 6 and
        fixture.Freed[2].Address == fixture.Created[3].Address and fixture.Freed[3].Address == fixture.Created[2].Address and
        ownedCount() == 0 and !fixture.ScriptMismatch;
}

fn abortRetry(real: *services.boot.BootServices, image_handle: base.Handle, persistent: bool, comptime label: []const u8) !void {
    var wrapped = try begin(real, image_handle, &.{}, &.{});
    var claims: claimtypes.Claims = .{ .Paging = .{ .BootServices = &wrapped } };
    try claims.Paging.initialize();
    claims.Handoff = try initializedState(&wrapped);
    if (efi.pages.acquire(&wrapped, null, inputs.PHYSICAL_LIMIT, 1, &claims.Image.Backing) != .Acquired) return error.AllocationFailed;
    var source: [*]align(8) u8 = undefined;
    if (real.AllocatePool(.LoaderData, inputs.PAGE_BYTES, &source) != codes.SUCCESS) return error.AllocationFailed;
    fixture.Source = source;
    claims.Source.Allocation = source;
    if (persistent) {
        fixture.FailFreeCalls = &.{ 4, 5 };
    } else {
        fixture.FailFreeCalls = &.{ 1, 4 };
        fixture.FailPoolFreeCall = 1;
    }

    const completed = abort.finish(&claims);
    const other_claims_released = claims.Image.Backing == null and !claims.Image.Untrusted and claims.Source.isEmpty() and fixture.Source == null and
        claims.Handoff.?.Stack == null and claims.Handoff.?.Parameters == null and fixture.AllocateCalls == 4;
    const root = fixture.Created[0].Address;
    const first_pass = fixture.Freed[0].Address == fixture.Created[2].Address and
        fixture.Freed[1].Address == fixture.Created[1].Address and fixture.Freed[2].Address == fixture.Created[3].Address and
        fixture.Freed[3].Address == root;
    const outcome = if (persistent)
        !completed and claims.Paging.RootOwned and @intFromPtr(claims.Paging.L4) == root and ownedCount() == 1 and
            fixture.FreeCalls == 5 and fixture.Freed[4].Address == root and fixture.PoolFreeCalls == 1
    else
        completed and !claims.Paging.RootOwned and ownedCount() == 0 and fixture.FreeCalls == 6 and
            fixture.Freed[4].Address == root and fixture.Freed[5].Address == fixture.Created[2].Address and fixture.PoolFreeCalls == 2;
    const pool_calls = fixture.PoolFreeCalls;
    const recovered = abort.finish(&claims);
    const idempotent = abort.finish(&claims);
    finish(other_claims_released and first_pass and outcome and recovered and idempotent and ownedCount() == 0 and
        !claims.Paging.RootOwned and fixture.AllocateCalls == 4 and fixture.FreeCalls == 6 and fixture.PoolFreeCalls == pool_calls, label);
}

fn retrySeparateTables(real: *services.boot.BootServices, image_handle: base.Handle) !void {
    var wrapped = try begin(real, image_handle, &.{}, &.{});
    var claims: claimtypes.Claims = .{ .Paging = .{ .BootServices = &wrapped } };
    try claims.Paging.initialize();
    const first = @intFromPtr(try claims.Paging.allocateTable());
    const second = @intFromPtr(try claims.Paging.allocateTable());
    fixture.FailFreeCalls = &.{ 1, 3 };
    const released = abort.finish(&claims);
    finish(released and !claims.Paging.RootOwned and claims.Paging.Ledger == null and claims.Paging.AllocatedCount == 0 and
        fixture.AllocateCalls == 4 and fixture.FreeCalls == 6 and fixture.Freed[0].Address == second and
        fixture.Freed[1].Address == second and fixture.Freed[2].Address == first and fixture.Freed[3].Address == first and
        ownedCount() == 0, labels.ABORT_TABLE_RETRY);
}

fn initializedState(wrapped: *services.boot.BootServices) !handofftypes.Handoff {
    var state: handofftypes.Handoff = .{ .BootServices = wrapped, .PhysicalLimit = inputs.PHYSICAL_LIMIT };
    try handoff.initialize(&state);
    return state;
}

fn begin(real: *services.boot.BootServices, image_handle: base.Handle, maps: []const types.MapReply, exits: []const base.Status) !services.boot.BootServices {
    if (!cleanup()) return errors.HandoffError.AllocationFailed;
    fixture = .{ .Real = real, .ImageHandle = image_handle, .MapScript = maps, .ExitScript = exits };
    active = true;
    var wrapped = real.*;
    wrapped.AllocatePages = allocatePages;
    wrapped.FreePages = freePages;
    wrapped.FreePool = freePool;
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
    for (fixture.FailFreeCalls) |failure| {
        if (failure == fixture.FreeCalls) return codes.DEVICE_ERROR;
    }
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

fn freePool(source: [*]align(8) u8) callconv(convention.CALLING_CONVENTION) base.Status {
    fixture.PoolFreeCalls += 1;
    if (fixture.Source == null or fixture.Source.? != source) {
        fixture.ScriptMismatch = true;
        return codes.DEVICE_ERROR;
    }
    if (fixture.FailPoolFreeCall == fixture.PoolFreeCalls) return codes.DEVICE_ERROR;
    const result = fixture.Real.FreePool(source);
    if (result == codes.SUCCESS) fixture.Source = null;
    return result;
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
    if (fixture.PublishedParams) |params| {
        if (!mapPublished(params)) fixture.ScriptMismatch = true;
    }
    fixture.ExitKeys[call] = key;
    return fixture.ExitScript[call];
}

fn mapPublished(params: *const boot.types.params.BootParams) bool {
    if (params.Retirement.LedgerPhysical == 0 or fixture.CreatedCount < 3) return false;
    const latest = fixture.Created[fixture.CreatedCount - 1];
    const ledger: *const boot.types.retirement.Ledger = @ptrFromInt(params.Retirement.LedgerPhysical);
    return params.MemoryMap.Entries == latest.Address and params.Retirement.MapPages == latest.Pages and
        ledger.MapPhysical == latest.Address and ledger.MapPages == latest.Pages;
}
