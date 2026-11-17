//! Disposable Root Lifetime Regressions

const std = @import("std");

const address = @import("utils").address;
const bits = @import("utils").bits;
const common = @import("common");
const decompose = @import("utils").address.decompose;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").verify;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const Kagami = kagami.types.kagami.Kagami;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const before = pmm.state.getStatistics();
    const payload = try pmm.allocate.single.allocatePage();
    var owns_payload = true;
    defer if (owns_payload) pmm.free.single.freePage(payload);
    const bytes: [*]u8 = @ptrFromInt(address.translate.physToVirt(payload));
    @memset(bytes[0..sizes.PAGE_SIZE], inputs.DIRTY_BYTE);
    const root = try kagami.create.create();
    defer if (kagami.create.owns(root)) {
        _ = kagami.destroy.destroy(root);
    };
    const physical = root.PML4Physical;
    kagami.destroy.reference(root);
    verify.require(root.ReferenceCount == 2, labels.KAGAMI_REFERENCE);
    kagami.destroy.release(root);
    verify.require(root.ReferenceCount == 1 and root.PML4Physical == physical and kagami.create.owns(root), labels.KAGAMI_REFERENCE);
    verify.require(kagami.retain.acquire(root), labels.KAGAMI_EXECUTION);
    const refused = kagami.destroy.destroy(root);
    verify.require(refused == .Refused and root.ExecutionOwners == 1 and root.ReferenceCount == 1 and
        root.PML4Physical == physical, labels.KAGAMI_EXECUTION);
    kagami.destroy.reference(root);
    kagami.destroy.release(root);
    verify.require(root.ExecutionOwners == 1 and root.ReferenceCount == 2 and kagami.create.owns(root), labels.KAGAMI_EXECUTION);
    verify.require(kagami.retain.release(root) and !kagami.retain.release(root) and root.ExecutionOwners == 0, labels.KAGAMI_EXECUTION);
    kagami.destroy.release(root);
    verify.require(root.ReferenceCount == 1 and kagami.create.owns(root), labels.KAGAMI_REFERENCE);
    activeRestriction(root);
    try kagami.enter.enter(root, inputs.MAP_ADDRESS, payload, kagami.constants.protection.USER_WRITE | kagami.constants.protection.WIRED);
    const tables = root.TablePages;
    const descriptor = (@intFromPtr(root) & ~sizes.PAGE_MASK) - layout.PHYSMAP_BASE;
    const directory = kagami.tables.walk.getPML4(root.PML4Physical).Entries[decompose.extractPML4Index(inputs.MAP_ADDRESS)].getPhysicalAddress();
    const middle = kagami.tables.walk.getTableFromPhysical(directory).Entries[decompose.extractPDPTIndex(inputs.MAP_ADDRESS)].getPhysicalAddress();
    const leaf = kagami.tables.walk.getTableFromPhysical(middle).Entries[decompose.extractPDIndex(inputs.MAP_ADDRESS)].getPhysicalAddress();
    const frames = [_]u64{ root.PML4Physical, directory, middle, leaf };
    const before_destroy = pmm.state.getStatistics();
    const destroyed = kagami.destroy.destroy(root);
    const after_destroy = pmm.state.getStatistics();
    var released = !bits.operations.testBit(pmm.state.getState().Bitmap, descriptor / sizes.PAGE_SIZE);
    for (frames) |frame| released = released and !bits.operations.testBit(pmm.state.getState().Bitmap, frame / sizes.PAGE_SIZE);
    verify.require(destroyed == .Destroyed and !kagami.create.owns(root) and released and tables == frames.len and
        after_destroy.FreePages >= before_destroy.FreePages + tables and
        bits.operations.testBit(pmm.state.getState().Bitmap, payload / sizes.PAGE_SIZE) and
        std.mem.allEqual(u8, bytes[0..sizes.PAGE_SIZE], inputs.DIRTY_BYTE), labels.KAGAMI_PAYLOAD);
    pmm.free.single.freePage(payload);
    owns_payload = false;
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.KAGAMI_FREE);
}

fn activeRestriction(root: *Kagami) void {
    const original = kagami.state.getCurrentKagami();
    const original_physical = kagami.activate.getActivePML4();
    verify.require(kagami.activate.canActivate(original) and kagami.activate.canActivate(root), labels.KAGAMI_ACTIVE);
    defer kagami.activate.activate(original);
    kagami.activate.activate(root);
    verify.require(kagami.state.getCurrentKagami() == root and kagami.activate.isActive(root), labels.KAGAMI_ACTIVE);
    const refused = kagami.destroy.destroy(root);
    verify.require(refused == .Refused and kagami.create.owns(root) and root.ReferenceCount == 1 and root.TablePages == 1, labels.KAGAMI_ACTIVE);
    kagami.activate.activate(original);
    verify.require(kagami.state.getCurrentKagami() == original and
        kagami.activate.getActivePML4() == original_physical and kagami.activate.isActive(original), labels.KAGAMI_RESTORE);
}
