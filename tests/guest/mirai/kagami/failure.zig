//! Unpublished Table Metadata Failure And Owner Transfer

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.tables;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.tables;
const pmm = @import("mirai").pmm;
const verify = @import("tests").guest.support.verify;

const sizes = common.constants.memory.sizes;
const Kagami = kagami.types.kagami.Kagami;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const before = pmm.state.getStatistics();
    const payload = try pmm.allocate.single.allocatePageZeroed();
    var live_payload = true;
    defer if (live_payload) pmm.free.single.freePage(payload);
    const root = try kagami.create.create();
    var live_root = true;
    defer if (live_root) verify.require(kagami.destroy.destroy(root) == .Destroyed, labels.RECOVERY);
    try kagami.enter.enter(root, inputs.SPARSE_ADDRESS, payload, kagami.constants.protection.USER_WRITE);
    var index: usize = 1;
    var rejected = false;
    while (index < sizes.ENTRIES_PER_PAGE_TABLE) : (index += 1) {
        const virtual = inputs.SPARSE_ADDRESS + index * sizes.LARGE_PAGE_SIZE;
        const snapshot = pmm.state.getStatistics();
        const search = pmm.state.getState().SearchStart;
        const tables = root.TablePages;
        const residents = root.ResidentPages;
        budget.arm(1);
        if (kagami.enter.enter(root, virtual, payload, kagami.constants.protection.USER_WRITE)) |_| {
            budget.clear();
        } else |failure| {
            budget.clear();
            rejected = failure == error.OutOfMemory and root.TablePages == tables and root.ResidentPages == residents and
                kagami.extract.extract(root, virtual) == null and kagami.extract.extract(root, inputs.SPARSE_ADDRESS) == payload and
                kagami.tables.ownership.reset(root) and search == pmm.state.getState().SearchStart and
                std.meta.eql(snapshot, pmm.state.getStatistics());
            break;
        }
    }
    verify.require(rejected, labels.METADATA_FAILURE);
    try kagami.enter.enter(root, inputs.SPARSE_ADDRESS + index * sizes.LARGE_PAGE_SIZE, payload, kagami.constants.protection.USER_WRITE);
    transfer(root);
    budget.arm(0);
    verify.require(kagami.destroy.destroy(root) == .Destroyed, labels.RECOVERY);
    live_root = false;
    pmm.free.single.freePage(payload);
    live_payload = false;
    budget.clear();
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.RECOVERY);
}

fn transfer(root: *Kagami) void {
    const before = pmm.state.getStatistics();
    const count = root.TablePages;
    var target = root.*;
    verify.require(!kagami.tables.ownership.transfer(root, &target) and kagami.tables.ownership.reset(root), labels.TRANSFER);
    target.Frames = null;
    target.TablePages = 0;
    budget.arm(0);
    verify.require(kagami.tables.ownership.transfer(root, &target) and root.Frames == null and root.TablePages == 0 and
        target.TablePages == count and kagami.tables.ownership.reset(&target) and
        kagami.tables.ownership.owns(&target, target.PML4Physical) and !kagami.tables.ownership.owns(root, root.PML4Physical), labels.TRANSFER);
    verify.require(kagami.tables.ownership.transfer(&target, root) and target.Frames == null and target.TablePages == 0 and
        root.TablePages == count and kagami.tables.ownership.reset(root) and kagami.create.owns(root) and
        std.meta.eql(before, pmm.state.getStatistics()), labels.TRANSFER);
    budget.clear();
}
