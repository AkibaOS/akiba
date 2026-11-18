//! Mapping Boundary Descriptor Membership Validation

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.tables;
const pmm = @import("mirai").pmm;
const verify = @import("tests").verify;

const Kagami = kagami.types.kagami.Kagami;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const payload = try pmm.allocate.single.allocatePage();
    defer pmm.free.single.freePage(payload);
    budget.arm(0);
    refused(@ptrFromInt(common.constants.memory.sizes.PAGE_SIZE), payload);
    budget.clear();
    const released = try kagami.create.create();
    verify.require(kagami.destroy.destroy(released) == .Destroyed, labels.DESCRIPTOR_RECOVERY);
    budget.arm(0);
    refused(released, payload);
    budget.clear();
    const root = try kagami.create.create();
    defer _ = kagami.destroy.destroy(root);
    try kagami.enter.enter(root, inputs.MAP_ADDRESS, payload, kagami.constants.protection.USER_WRITE);
    var foreign = root.*;
    budget.arm(0);
    refused(&foreign, payload);
    refused(@ptrFromInt(@intFromPtr(root) + @alignOf(Kagami)), payload);
    try kagami.protect.protect(root, inputs.MAP_ADDRESS, kagami.constants.protection.USER_WRITE);
    try kagami.enter.enterReplace(root, inputs.MAP_ADDRESS, payload, kagami.constants.protection.USER_WRITE);
    verify.require(kagami.create.owns(root) and root.ResidentPages == 1 and
        kagami.extract.extract(root, inputs.MAP_ADDRESS) == payload, labels.DESCRIPTOR_RECOVERY);
}

fn refused(root: *Kagami, physical: u64) void {
    const before = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    const kernel = kagami.state.getCurrentKagami();
    const entered = if (kagami.enter.enter(root, inputs.MAP_ADDRESS, physical, kagami.constants.protection.USER_WRITE)) |_| false else |failure| failure == error.PermissionDenied;
    const replaced = if (kagami.enter.enterReplace(root, inputs.MAP_ADDRESS, physical, kagami.constants.protection.USER_WRITE)) |_| false else |failure| failure == error.PermissionDenied;
    const protected = if (kagami.protect.protect(root, inputs.MAP_ADDRESS, kagami.constants.protection.USER_WRITE)) |_| false else |failure| failure == error.PermissionDenied;
    verify.require(entered and replaced and protected and kagami.remove.remove(root, inputs.MAP_ADDRESS) == null and
        kagami.remove.removeOwned(root, inputs.MAP_ADDRESS, physical) == null and !kagami.activate.isActive(root) and
        !kagami.activate.canActivate(root) and kagami.extract.lookup(root, inputs.MAP_ADDRESS) == null and
        !kagami.create.owns(root) and kagami.state.getCurrentKagami() == kernel and
        pmm.state.getState().SearchStart == search and std.meta.eql(before, pmm.state.getStatistics()), labels.DESCRIPTOR_REFUSAL);
}
