//! Growable Owned Persona Page Populations

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.memory;
const pmm = @import("mirai").pmm;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const Kata = kata.types.kata.Kata;
const Record = user.types.record.Record;

var retained: [2][inputs.OWNED_POPULATION_PAGES]?*Record = .{
    [_]?*Record{null} ** inputs.OWNED_POPULATION_PAGES,
    [_]?*Record{null} ** inputs.OWNED_POPULATION_PAGES,
};

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const first = try kata.create.create();
    defer kata.destroy.destroy(first) catch |failure| verify.failure(failure);
    const second = try kata.create.create();
    defer kata.destroy.destroy(second) catch |failure| verify.failure(failure);
    try user.memory.allocate.allocate(first, inputs.USER_ADDRESS);
    try user.memory.release.releaseAll(first);
    const before = pmm.state.getStatistics();
    const owners = [_]*Kata{ first, second };
    var stable = true;
    for (0..inputs.OWNED_POPULATION_PAGES) |index| {
        const virtual = inputs.USER_ADDRESS + index * sizes.PAGE_SIZE;
        for (owners, 0..) |owner, owner_index| {
            try user.memory.allocate.allocate(owner, virtual);
            const record = user.state.ledger.find(owner, virtual).?;
            retained[owner_index][index] = record;
            const bytes: [*]u8 = @ptrFromInt(layout.PHYSMAP_BASE + record.Backing.PA);
            stable = stable and std.mem.allEqual(u8, bytes[0..sizes.PAGE_SIZE], 0);
            @memset(bytes[0..sizes.PAGE_SIZE], marker(owner_index, index));
        }
    }
    for (owners, 0..) |owner, owner_index| {
        stable = stable and owner.AddressSpace.?.ResidentPages == inputs.OWNED_POPULATION_PAGES;
        for (0..inputs.OWNED_POPULATION_PAGES) |index| {
            const virtual = inputs.USER_ADDRESS + index * sizes.PAGE_SIZE;
            const record = user.state.ledger.find(owner, virtual);
            stable = stable and record == retained[owner_index][index] and record.?.Owner == owner and
                record.?.Root == owner.AddressSpace and user.state.ledger.findRoot(owner.AddressSpace.?, virtual) == record and
                user.state.backing.find(record.?.Backing.PA) == record.?.Backing;
        }
    }
    verify.require(stable, labels.USER_POPULATION);
    const count = user.state.ledger.count();
    const live = pmm.state.getStatistics();
    budget.arm(0);
    verify.require(reject(first, inputs.USER_ADDRESS, retained[1][0].?.Backing.PA) and
        reject(second, inputs.USER_ADDRESS + inputs.OWNED_POPULATION_PAGES * sizes.PAGE_SIZE, retained[0][0].?.Backing.PA) and
        user.state.ledger.count() == count and std.meta.eql(live, pmm.state.getStatistics()), labels.USER_INDEX_UNIQUE);
    try user.memory.release.releaseAll(first);
    for (0..inputs.OWNED_POPULATION_PAGES) |index| {
        const virtual = inputs.USER_ADDRESS + index * sizes.PAGE_SIZE;
        const record = user.state.ledger.find(second, virtual);
        const bytes: [*]const u8 = @ptrFromInt(layout.PHYSMAP_BASE + record.?.Backing.PA);
        stable = stable and user.state.ledger.find(first, virtual) == null and record == retained[1][index] and
            std.mem.allEqual(u8, bytes[0..sizes.PAGE_SIZE], marker(1, index));
    }
    verify.require(stable and first.AddressSpace.?.ResidentPages == 0 and
        second.AddressSpace.?.ResidentPages == inputs.OWNED_POPULATION_PAGES, labels.USER_POPULATION_RELEASE);
    try user.memory.release.releaseAll(second);
    budget.clear();
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.USER_POPULATION_UNWIND);
}

fn reject(owner: *Kata, virtual: u64, physical: u64) bool {
    if (user.state.ledger.register(owner, virtual, physical)) |unexpected| {
        user.state.ledger.unregister(unexpected);
        return false;
    } else |failure| return failure == error.AlreadyOwned;
}

fn marker(owner: usize, index: usize) u8 {
    return @intCast((owner + index) % std.math.maxInt(u8) + 1);
}
