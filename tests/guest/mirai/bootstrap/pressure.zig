//! Bounded Owned Ledger Pressure And Partial Image Rollback

const std = @import("std");

const bootstrap = @import("mirai").bootstrap;
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

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const before = pmm.state.getStatistics();
    const initial = owned();
    const scratch = try kata.create.create();
    var alive = true;
    defer if (alive) kata.destroy.destroy(scratch) catch |failure| verify.failure(failure);
    var count: u64 = 0;
    while (owned() < user.constants.limits.MAX_OWNED_PAGES - 2) : (count += 1) {
        try user.memory.allocate.allocate(scratch, inputs.PRESSURE_ADDRESS + count * inputs.PAGE_BYTES);
    }
    const full = pmm.state.getStatistics();
    const held = owned();
    const failed_id = scratch.ID + 1;
    var rejected = false;
    if (bootstrap.image.prepare.prepare(thread.state.getCurrent().?.Owner, &VALID, .{
        .StackBase = inputs.STACK_ADDRESS,
        .StackPages = 2,
    })) |unexpected| {
        try bootstrap.image.abort.abort(unexpected);
    } else |failure| {
        rejected = failure == error.OwnershipCapacity;
    }
    const rolled_back = rejected and count != 0 and owned() == held and scratch.AddressSpace.ResidentPages == count and
        std.meta.eql(full, pmm.state.getStatistics()) and kata.state.findByID(failed_id) == null and
        kata.completion.ownerOf(failed_id) == null;
    const probe = try kata.create.create();
    const reserved_then_released = probe.ID == failed_id + 1;
    try kata.destroy.destroy(probe);
    try kata.destroy.destroy(scratch);
    alive = false;
    verify.require(rolled_back and reserved_then_released and owned() == initial and
        std.meta.eql(before, pmm.state.getStatistics()), labels.ROLLBACK);
}

fn owned() usize {
    var count: usize = 0;
    for (0..user.constants.limits.MAX_OWNED_PAGES) |index| {
        if (user.state.ledger.at(index) != null) count += 1;
    }
    return count;
}
