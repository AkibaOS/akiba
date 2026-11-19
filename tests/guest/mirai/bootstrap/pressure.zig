//! Partial Image Allocation Refusal And Ownership Rollback

const std = @import("std");

const bootstrap = @import("mirai").bootstrap;
const budget = @import("tests").guest.support.allocation;
const fixture = @import("tests").fast.shared.elf.fixture;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.elf;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.elf;
const pmm = @import("mirai").pmm;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").verify;

const VALID = fixture.create();
const PARAMETERS: [inputs.STARTUP_PARAMETER_BYTES]u8 = @splat(inputs.STARTUP_PARAMETER_MASK);

var threshold: usize = 0;
var observed: usize = 0;
var startup_address: ?u64 = null;
var startup_owner: u64 = 0;
var saw_startup: bool = false;

pub fn run() !void {
    const options: bootstrap.types.image.Options = .{ .StackBase = inputs.STACK_ADDRESS, .StackPages = inputs.PRESSURE_PAGES };
    try refuse(options, labels.ROLLBACK);
    var handoff = options;
    handoff.Startup = .{ .Identity = labels.STARTUP_IDENTITY, .Parameters = &PARAMETERS };
    try refuse(handoff, labels.STARTUP_ROLLBACK);
}

fn refuse(options: bootstrap.types.image.Options, comptime label: []const u8) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const launcher = thread.state.getCurrent().?.Owner;
    const warm = try bootstrap.image.prepare.prepare(launcher, &VALID, options);
    startup_address = if (options.Startup != null) warm.Thread.User.Argument else null;
    saw_startup = false;
    try bootstrap.image.abort.abort(warm);
    const before = pmm.state.getStatistics();
    const initial = user.state.ledger.count();
    const scratch = try kata.create.create();
    var alive = true;
    defer if (alive) kata.destroy.destroy(scratch) catch |failure| verify.failure(failure);
    for (0..inputs.PRESSURE_PAGES) |index|
        try user.memory.allocate.allocate(scratch, inputs.PRESSURE_ADDRESS + index * inputs.PAGE_BYTES);
    const full = pmm.state.getStatistics();
    const held = user.state.ledger.count();
    threshold = held + inputs.PRESSURE_PAGES;
    observed = held;
    const failed_id = scratch.ID + 1;
    startup_owner = failed_id;
    budget.armWhen(partial);
    var rejected = false;
    if (bootstrap.image.prepare.prepare(launcher, &VALID, options)) |unexpected| {
        budget.clear();
        try bootstrap.image.abort.abort(unexpected);
    } else |failure| {
        rejected = failure == error.OutOfMemory;
    }
    budget.clear();
    const observed_partial = if (startup_address != null) saw_startup else observed >= threshold;
    const rolled_back = rejected and observed_partial and user.state.ledger.count() == held and
        scratch.AddressSpace.?.ResidentPages == inputs.PRESSURE_PAGES and
        std.meta.eql(full, pmm.state.getStatistics()) and kata.state.findByID(failed_id) == null and
        kata.completion.storage.ownerOf(failed_id) == null;
    const probe = try kata.create.create();
    const reserved_then_released = probe.ID == failed_id + 1;
    try kata.destroy.destroy(probe);
    try kata.destroy.destroy(scratch);
    alive = false;
    verify.require(rolled_back and reserved_then_released and user.state.ledger.count() == initial and
        std.meta.eql(before, pmm.state.getStatistics()), label);
}

fn partial() bool {
    if (startup_address) |address| {
        const owner = kata.state.findByID(startup_owner) orelse return false;
        if (user.state.ledger.find(owner, address) == null or user.state.ledger.find(owner, address + inputs.PAGE_BYTES) != null) return false;
        saw_startup = true;
        return true;
    }
    observed = @max(observed, user.state.ledger.count());
    return observed >= threshold;
}
