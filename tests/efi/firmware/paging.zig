//! Firmware Owned Loader Table Growth And Failure Recovery

const base = @import("hikari").efi.types.base;
const control = @import("asm").cpu.control;
const convention = @import("hikari").efi.constants.convention;
const indices = @import("common").constants.paging.indices;
const inputs = @import("tests").constants.firmware;
const labels = @import("tests").strings.firmware;
const memory = @import("hikari").efi.types.memory;
const output = @import("tests").efi.firmware.run;
const paging = @import("hikari").paging;
const retirement = @import("shared").boot.types.retirement;
const retirementlimits = @import("shared").boot.constants.retirement;
const services = @import("hikari").efi.types.services;
const status = @import("hikari").efi.status;
const statuses = @import("hikari").efi.constants.status;

const Setup = paging.types.setup.PageTableSetup;
const Table = paging.types.table.PageTable;

var real_services: *services.boot.BootServices = undefined;
var allocated: usize = 0;
var freed: usize = 0;
var allocation_budget: ?usize = null;
var release_budget: ?usize = null;
var zero_after: ?usize = null;
var zero_owned: bool = false;
var zero_releases: usize = 0;

pub fn run(real: *services.boot.BootServices) !void {
    real_services = real;
    allocated = 0;
    freed = 0;
    var wrapped = real.*;
    wrapped.AllocatePages = allocatePages;
    wrapped.FreePages = freePages;
    try growth(&wrapped);
    try pressure(&wrapped);
    try retained(&wrapped);
    try zeroRoot(&wrapped);
    try zeroChild(&wrapped);
    for (0..inputs.PAGING_RELEASE_PAGES) |position| try release(&wrapped, position);
    try active(&wrapped);
}

fn growth(wrapped: *services.boot.BootServices) !void {
    var setup: Setup = .{ .BootServices = wrapped };
    try setup.initialize();
    defer _ = setup.deinitialize();
    var first: ?*Table = null;
    var last: ?*Table = null;
    for (0..inputs.OWNED_TABLES) |index| {
        const table = try setup.allocateTable();
        if (index == 0) first = table;
        last = table;
    }
    const inventory = setup.retirementInventory();
    var remaining = inventory.ChildFrames;
    var physical = inventory.LedgerPhysical;
    while (remaining != 0 and physical != 0) {
        const node: *const retirement.Ledger = @ptrFromInt(physical);
        const count = (remaining - 1) % retirementlimits.LEDGER_CAPACITY + 1;
        if (node.Count != count) break;
        remaining -= count;
        physical = node.NextPhysical;
    }
    output.require(inventory.ChildFrames == inputs.OWNED_TABLES and remaining == 0 and physical == 0 and first != last and
        first.?.Entries[0].toRaw() == 0 and last.?.Entries[0].toRaw() == 0 and
        @sizeOf(retirement.Ledger) <= inputs.PAGE_BYTES, labels.PAGING_GROWTH);
    const released = setup.deinitialize();
    output.require(released and setup.deinitialize() and !setup.RootOwned and
        setup.AllocatedCount == 0 and allocated == freed, labels.PAGING_RELEASE);
}

fn pressure(wrapped: *services.boot.BootServices) !void {
    allocation_budget = 0;
    var initial: Setup = .{ .BootServices = wrapped };
    const refused = if (initial.initialize()) |_| false else |failure| failure == error.AllocationFailed;
    allocation_budget = null;
    const released = initial.deinitialize();
    output.require(refused and released and !initial.RootOwned and initial.Rejected == null and allocated == freed, labels.PAGING_ROOT_PRESSURE);

    var setup: Setup = .{ .BootServices = wrapped };
    try setup.initialize();
    defer _ = setup.deinitialize();
    for (0..inputs.PAGING_RESERVATION_POINTS) |position| {
        const baseline = allocated - freed;
        allocation_budget = position;
        const failed = refusesTable(&setup);
        allocation_budget = null;
        output.require(failed and setup.Ledger == null and setup.AllocatedCount == 0 and
            allocated - freed == baseline, labels.PAGING_INITIAL_PRESSURE);
    }
    const first = try setup.allocateTable();
    allocation_budget = 0;
    const failed = refusesTable(&setup);
    allocation_budget = null;
    output.require(failed and setup.AllocatedCount == 1 and first.Entries[0].toRaw() == 0, labels.PAGING_EXISTING_PRESSURE);
    while (setup.AllocatedCount < retirementlimits.LEDGER_CAPACITY) _ = try setup.allocateTable();
    const previous = setup.Ledger;
    for (0..inputs.PAGING_RESERVATION_POINTS) |position| {
        const baseline = allocated - freed;
        allocation_budget = position;
        const rejected = refusesTable(&setup);
        allocation_budget = null;
        output.require(rejected and setup.Ledger == previous and
            setup.AllocatedCount == retirementlimits.LEDGER_CAPACITY and allocated - freed == baseline and
            first.Entries[0].toRaw() == 0, labels.PAGING_BOUNDARY_PRESSURE);
    }
    _ = try setup.allocateTable();
    output.require(setup.deinitialize() and allocated == freed, labels.PAGING_PRESSURE_RECOVERY);
}

fn retained(wrapped: *services.boot.BootServices) !void {
    var setup: Setup = .{ .BootServices = wrapped };
    try setup.initialize();
    defer _ = setup.deinitialize();
    const baseline = allocated - freed;
    allocation_budget = 1;
    release_budget = 0;
    const refused = refusesTable(&setup);
    allocation_budget = null;
    release_budget = null;
    output.require(refused and setup.Ledger != null and setup.Ledger.?.Count == 0 and
        setup.AllocatedCount == 0 and allocated - freed == baseline + 1, labels.PAGING_RETAINED_METADATA);
    _ = try setup.allocateTable();
    output.require(setup.AllocatedCount == 1 and setup.deinitialize() and allocated == freed, labels.PAGING_RETAINED_RECOVERY);
}

fn zeroRoot(wrapped: *services.boot.BootServices) !void {
    var setup: Setup = .{ .BootServices = wrapped };
    const baseline = zero_releases;
    zero_after = 0;
    const refused = if (setup.initialize()) |_| false else |failure| failure == error.AllocationFailed;
    const pending = setup.Rejected != null and setup.Rejected.?.Physical == 0 and setup.Rejected.?.Pages == 1 and
        !setup.RootOwned and setup.getL4Address() == 0 and zero_owned;
    release_budget = 0;
    const still_owned = !setup.deinitialize() and setup.Rejected != null and zero_owned;
    const released = setup.deinitialize() and setup.deinitialize();
    output.require(refused and pending and still_owned and released and setup.Rejected == null and !zero_owned and
        zero_releases == baseline + 1 and allocated == freed, labels.PAGING_ZERO_ROOT);
}

fn zeroChild(wrapped: *services.boot.BootServices) !void {
    var setup: Setup = .{ .BootServices = wrapped };
    try setup.initialize();
    const baseline = zero_releases;
    zero_after = 1;
    release_budget = 0;
    const refused = refusesTable(&setup);
    const both_retained = setup.Rejected != null and setup.Rejected.?.Physical == 0 and zero_owned and
        setup.Ledger != null and setup.Ledger.?.Count == 0 and setup.AllocatedCount == 0 and
        setup.getL4Address() == 0 and allocated - freed == 2;
    release_budget = 0;
    const only_zero_retained = !setup.deinitialize() and setup.Rejected != null and zero_owned and
        !setup.RootOwned and setup.Ledger == null and allocated == freed;
    const released = setup.deinitialize() and setup.deinitialize();
    output.require(refused and both_retained and only_zero_retained and released and setup.Rejected == null and
        !zero_owned and zero_releases == baseline + 1, labels.PAGING_ZERO_CHILD);
}

fn release(wrapped: *services.boot.BootServices, position: usize) !void {
    var setup: Setup = .{ .BootServices = wrapped };
    try setup.initialize();
    defer _ = setup.deinitialize();
    try setup.mapIdentity(0, inputs.PAGE_BYTES);
    const baseline = freed;
    output.require(allocated - freed == inputs.PAGING_RELEASE_PAGES, labels.PAGING_RELEASE_GEOMETRY);
    release_budget = position;
    const released = setup.deinitialize();
    release_budget = null;
    output.require(!released and setup.RootOwned and setup.Closing and freed - baseline == position, labels.PAGING_RELEASE_REFUSAL);
    const outstanding = allocated - freed;
    var represented: usize = 1;
    var cursor = setup.Ledger;
    var tables: usize = 0;
    while (cursor) |page| : (cursor = @ptrFromInt(page.NextPhysical)) {
        represented += 1 + page.Count;
        tables += page.Count;
    }
    const refused = refusesTable(&setup);
    const unmapped = if (setup.mapIdentity(inputs.PAGE_BYTES, inputs.PAGE_BYTES)) |_| false else |failure| failure == error.InvalidMapping;
    const physmap = if (setup.mapPhysmap()) |_| false else |failure| failure == error.InvalidMapping;
    output.require(represented == outstanding and tables == setup.AllocatedCount and
        refused and unmapped and physmap and setup.getL4Address() == 0 and
        allocated - freed == outstanding, labels.PAGING_CLOSING);
    allocation_budget = 0;
    const recovered = setup.deinitialize();
    allocation_budget = null;
    output.require(recovered and setup.deinitialize() and !setup.RootOwned and setup.Ledger == null and
        setup.AllocatedCount == 0 and allocated == freed, labels.PAGING_RELEASE_RETRY);
}

fn active(wrapped: *services.boot.BootServices) !void {
    var setup: Setup = .{ .BootServices = wrapped };
    try setup.initialize();
    const original = setup.L4;
    setup.L4 = @ptrFromInt(control.readCR3() & indices.ADDRESS_MASK);
    const baseline = freed;
    const released = setup.deinitialize();
    setup.L4 = original;
    output.require(!released and !setup.Closing and freed == baseline and setup.RootOwned and
        setup.deinitialize() and allocated == freed, labels.PAGING_ACTIVE);
}

fn refusesTable(setup: *Setup) bool {
    if (setup.allocateTable()) |_| return false else |failure| return failure == error.AllocationFailed;
}

fn allocatePages(kind: memory.AllocateType, usage: memory.MemoryType, pages: usize, address: *base.PhysicalAddress) callconv(convention.CALLING_CONVENTION) base.Status {
    if (allocation_budget) |remaining| {
        if (remaining == 0) return statuses.OUT_OF_RESOURCES;
    }
    if (zero_after) |remaining| {
        if (remaining == 0) {
            zero_after = null;
            if (kind != .MaxAddress or usage != .LoaderData or pages != 1 or zero_owned) return statuses.INVALID_PARAMETER;
            address.* = 0;
            zero_owned = true;
            return statuses.SUCCESS;
        }
        zero_after = remaining - 1;
    }
    const result = real_services.AllocatePages(kind, usage, pages, address);
    if (!status.isError(result)) {
        allocated += pages;
        if (allocation_budget) |remaining| allocation_budget = remaining - 1;
    }
    return result;
}

fn freePages(address: base.PhysicalAddress, pages: usize) callconv(convention.CALLING_CONVENTION) base.Status {
    if (release_budget) |remaining| {
        if (remaining == 0) {
            release_budget = null;
            return statuses.DEVICE_ERROR;
        }
    }
    if (address == 0) {
        if (!zero_owned or pages != 1) return statuses.INVALID_PARAMETER;
        zero_owned = false;
        zero_releases += 1;
        return statuses.SUCCESS;
    }
    const result = real_services.FreePages(address, pages);
    if (!status.isError(result)) {
        freed += pages;
        if (release_budget) |remaining| release_budget = remaining - 1;
    }
    return result;
}
