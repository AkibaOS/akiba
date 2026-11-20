//! Sparse Owned Table Population And Reclamation

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.tables;
const kagami = @import("mirai").kagami;
const labels = @import("tests").guest.strings.tables;
const pmm = @import("mirai").pmm;
const verify = @import("tests").guest.support.verify;

const sizes = common.constants.memory.sizes;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const warm = try kagami.create.create();
    verify.require(kagami.destroy.destroy(warm) == .Destroyed, labels.RECOVERY);
    const before = pmm.state.getStatistics();
    const payload = try pmm.allocate.single.allocatePageZeroed();
    var live_payload = true;
    defer if (live_payload) pmm.free.single.freePage(payload);
    const root = try kagami.create.create();
    var live_root = true;
    defer if (live_root) verify.require(kagami.destroy.destroy(root) == .Destroyed, labels.RELEASE);
    for (0..inputs.SPARSE_PAGES) |index|
        try kagami.enter.enter(root, address(index), payload, kagami.constants.protection.USER_WRITE);
    var stable = root.TablePages > inputs.SPARSE_PAGES and root.ResidentPages == inputs.SPARSE_PAGES;
    for (0..inputs.SPARSE_PAGES) |index|
        stable = stable and kagami.extract.extract(root, address(index)) == payload;
    verify.require(stable, labels.SPARSE);
    budget.arm(0);
    const destroyed = kagami.destroy.destroy(root);
    live_root = false;
    verify.require(destroyed == .Destroyed and !kagami.create.owns(root) and
        pmm.state.isAllocated(payload), labels.RELEASE);
    pmm.free.single.freePage(payload);
    live_payload = false;
    budget.clear();
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.RECOVERY);
}

fn address(index: usize) u64 {
    return inputs.SPARSE_ADDRESS + index * sizes.LARGE_PAGE_SIZE;
}
