//! Owned User Copy And Release Regressions

const std = @import("std");

const common = @import("common");
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.memory;
const pmm = @import("mirai").pmm;
const user = @import("mirai").user;
const verify = @import("tests").verify;

const layout = common.constants.memory.layout;
const protection = kagami.constants.protection;
const sizes = common.constants.memory.sizes;
const Kata = kata.types.kata.Kata;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const owner = try kata.create.create();
    defer kata.destroy.destroy(owner) catch |failure| verify.failure(failure);
    const other = try kata.create.create();
    defer kata.destroy.destroy(other) catch |failure| verify.failure(failure);
    try user.memory.allocate.allocate(owner, inputs.USER_ADDRESS);
    try user.memory.release.releaseAll(owner);
    const baseline = pmm.state.getStatistics();
    const baseline_kernel_tables = kagami.state.getKernelKagami().TablePages;
    try user.memory.allocate.allocate(owner, inputs.USER_ADDRESS);
    try user.memory.allocate.allocate(owner, inputs.USER_NEIGHBOR);
    var fresh: [sizes.PAGE_SIZE]u8 = undefined;
    try user.copy.transfer.read(owner, &fresh, inputs.USER_ADDRESS);
    verify.require(std.mem.allEqual(u8, &fresh, 0), labels.USER_ZERO);
    try user.copy.transfer.read(owner, &fresh, inputs.USER_NEIGHBOR);
    verify.require(std.mem.allEqual(u8, &fresh, 0), labels.USER_ZERO);
    allocationRejections(owner);
    verify.require(user.copy.transfer.validate(owner, inputs.USER_ADDRESS, user.constants.limits.MAX_COPY_BYTES, true) and
        user.copy.transfer.validate(owner, inputs.CROSS_ADDRESS, inputs.COPY_BYTES.len, true) and
        user.copy.transfer.validate(owner, layout.USER_SPACE_END, 0, false) and
        !user.copy.transfer.validate(owner, 0, 0, false) and
        !user.copy.transfer.validate(owner, layout.USER_SPACE_END, 2, false) and
        !user.copy.transfer.validate(owner, inputs.USER_ADDRESS, user.constants.limits.MAX_COPY_BYTES + 1, false), labels.USER_BOUNDS);
    try user.copy.transfer.write(owner, inputs.CROSS_ADDRESS, &inputs.COPY_BYTES);
    var copied: [inputs.COPY_BYTES.len]u8 = undefined;
    try user.copy.transfer.read(owner, &copied, inputs.CROSS_ADDRESS);
    verify.require(std.mem.eql(u8, &copied, &inputs.COPY_BYTES), labels.USER_CROSS);
    try wrongOwner(owner, other);
    try hole(owner);
    try overlap(owner);
    try crossPageOverlap(owner);
    ledgerProtection(owner, other);
    try invalidAlias(owner);
    referenceRestriction(owner);
    verify.require(owner.AddressSpace.?.ReferenceCount == 1, labels.USER_IN_USE);
    try sealedBoundary(owner);
    try release(owner, baseline, baseline_kernel_tables);
}

fn allocationRejections(owner: *Kata) void {
    const before = pmm.state.getStatistics();
    var duplicate = false;
    user.memory.allocate.allocate(owner, inputs.USER_ADDRESS) catch |failure| {
        duplicate = failure == error.AlreadyOwned;
    };
    var unaligned = false;
    user.memory.allocate.allocate(owner, inputs.USER_ADDRESS + inputs.SINGLE_BYTE) catch |failure| {
        unaligned = failure == error.AddressNotAligned;
    };
    var invalid = false;
    user.memory.allocate.allocate(owner, 0) catch |failure| {
        invalid = failure == error.InvalidUserRange;
    };
    verify.require(duplicate and unaligned and invalid and owner.AddressSpace.?.ResidentPages == 2 and
        std.meta.eql(before, pmm.state.getStatistics()), labels.USER_DUPLICATE);
}

fn wrongOwner(owner: *Kata, other: *Kata) !void {
    var destination = [_]u8{inputs.UNCHANGED_BYTE} ** inputs.COPY_BYTES.len;
    var rejected_read = false;
    user.copy.transfer.read(other, &destination, inputs.CROSS_ADDRESS) catch |failure| {
        rejected_read = failure == error.NotOwned;
    };
    var rejected_write = false;
    user.copy.transfer.write(other, inputs.CROSS_ADDRESS, &inputs.COPY_REPLACEMENT) catch |failure| {
        rejected_write = failure == error.NotOwned;
    };
    verify.require(rejected_read and rejected_write and std.mem.allEqual(u8, &destination, inputs.UNCHANGED_BYTE) and
        !user.copy.transfer.validate(other, inputs.CROSS_ADDRESS, inputs.COPY_BYTES.len, false), labels.USER_OWNER);
    try user.copy.transfer.read(owner, &destination, inputs.CROSS_ADDRESS);
    verify.require(std.mem.eql(u8, &destination, &inputs.COPY_BYTES), labels.USER_OWNER);
}

fn hole(owner: *Kata) !void {
    try user.copy.transfer.write(owner, inputs.HOLE_ADDRESS, inputs.COPY_BYTES[0..inputs.COPY_HALF]);
    var destination = [_]u8{inputs.UNCHANGED_BYTE} ** inputs.COPY_BYTES.len;
    var rejected_read = false;
    user.copy.transfer.read(owner, &destination, inputs.HOLE_ADDRESS) catch |failure| {
        rejected_read = failure == error.NotOwned;
    };
    var rejected_write = false;
    user.copy.transfer.write(owner, inputs.HOLE_ADDRESS, &inputs.COPY_REPLACEMENT) catch |failure| {
        rejected_write = failure == error.NotOwned;
    };
    verify.require(rejected_read and rejected_write and std.mem.allEqual(u8, &destination, inputs.UNCHANGED_BYTE) and
        !user.copy.transfer.validate(owner, inputs.HOLE_ADDRESS, inputs.COPY_BYTES.len, true), labels.USER_HOLE);
    var prefix: [inputs.COPY_HALF]u8 = undefined;
    try user.copy.transfer.read(owner, &prefix, inputs.HOLE_ADDRESS);
    verify.require(std.mem.eql(u8, &prefix, inputs.COPY_BYTES[0..inputs.COPY_HALF]), labels.USER_HOLE);
}

fn overlap(owner: *Kata) !void {
    const record = user.state.ledger.find(owner, inputs.USER_ADDRESS).?;
    const alias: [*]u8 = @ptrFromInt(layout.PHYSMAP_BASE + record.Backing.PA);
    var expected = inputs.OVERLAP_BYTES;
    std.mem.copyBackwards(u8, expected[inputs.OVERLAP_SHIFT..][0..inputs.OVERLAP_LENGTH], expected[0..inputs.OVERLAP_LENGTH]);
    try user.copy.transfer.write(owner, inputs.USER_ADDRESS, &inputs.OVERLAP_BYTES);
    try user.copy.transfer.write(owner, inputs.USER_ADDRESS + inputs.OVERLAP_SHIFT, alias[0..inputs.OVERLAP_LENGTH]);
    verify.require(std.mem.eql(u8, alias[0..expected.len], &expected), labels.USER_OVERLAP);
    try user.copy.transfer.write(owner, inputs.USER_ADDRESS, &inputs.OVERLAP_BYTES);
    try user.copy.transfer.read(owner, alias[inputs.OVERLAP_SHIFT..][0..inputs.OVERLAP_LENGTH], inputs.USER_ADDRESS);
    verify.require(std.mem.eql(u8, alias[0..expected.len], &expected), labels.USER_OVERLAP);
    expected = inputs.OVERLAP_BYTES;
    std.mem.copyForwards(u8, expected[0..inputs.OVERLAP_LENGTH], expected[inputs.OVERLAP_SHIFT..][0..inputs.OVERLAP_LENGTH]);
    try user.copy.transfer.write(owner, inputs.USER_ADDRESS, &inputs.OVERLAP_BYTES);
    try user.copy.transfer.write(owner, inputs.USER_ADDRESS, alias[inputs.OVERLAP_SHIFT..][0..inputs.OVERLAP_LENGTH]);
    verify.require(std.mem.eql(u8, alias[0..expected.len], &expected), labels.USER_OVERLAP);
    try user.copy.transfer.write(owner, inputs.USER_ADDRESS, &inputs.OVERLAP_BYTES);
    try user.copy.transfer.read(owner, alias[0..inputs.OVERLAP_LENGTH], inputs.USER_ADDRESS + inputs.OVERLAP_SHIFT);
    verify.require(std.mem.eql(u8, alias[0..expected.len], &expected), labels.USER_OVERLAP);
}

fn crossPageOverlap(owner: *Kata) !void {
    const first = user.state.ledger.find(owner, inputs.USER_ADDRESS).?;
    const second = user.state.ledger.find(owner, inputs.USER_NEIGHBOR).?;
    const first_alias: [*]u8 = @ptrFromInt(layout.PHYSMAP_BASE + first.Backing.PA);
    const second_alias: [*]u8 = @ptrFromInt(layout.PHYSMAP_BASE + second.Backing.PA);
    const source = first_alias[sizes.PAGE_SIZE - inputs.COPY_BYTES.len .. sizes.PAGE_SIZE];
    @memcpy(source, &inputs.COPY_BYTES);
    try user.copy.transfer.write(owner, inputs.CROSS_ADDRESS, source);
    var copied: [inputs.COPY_BYTES.len]u8 = undefined;
    try user.copy.transfer.read(owner, &copied, inputs.CROSS_ADDRESS);
    verify.require(std.mem.eql(u8, &copied, &inputs.COPY_BYTES), labels.USER_CROSS_OVERLAP);
    try user.copy.transfer.write(owner, inputs.CROSS_ADDRESS, &inputs.COPY_BYTES);
    const destination = second_alias[0..inputs.COPY_BYTES.len];
    try user.copy.transfer.read(owner, destination, inputs.CROSS_ADDRESS);
    verify.require(std.mem.eql(u8, destination, &inputs.COPY_BYTES), labels.USER_CROSS_OVERLAP);
    try user.copy.transfer.write(owner, inputs.CROSS_ADDRESS, &inputs.COPY_BYTES);
}

fn ledgerProtection(owner: *Kata, other: *Kata) void {
    const first = user.state.ledger.find(owner, inputs.USER_ADDRESS).?;
    const second = user.state.ledger.find(owner, inputs.USER_NEIGHBOR).?;
    const root = owner.AddressSpace.?;
    const tables = root.TablePages;
    const before = pmm.state.getStatistics();
    verify.require(kagami.remove.remove(root, inputs.USER_ADDRESS) == null and
        kagami.remove.removeRange(root, inputs.USER_ADDRESS, 2) == 0 and
        kagami.remove.removeOwned(root, inputs.USER_ADDRESS, second.Backing.PA) == null, labels.USER_LEDGER);
    var rejected_replacement = false;
    kagami.enter.enterReplace(root, inputs.USER_ADDRESS, second.Backing.PA, protection.USER_WRITE) catch |failure| {
        rejected_replacement = failure == error.PermissionDenied;
    };
    var rejected_alias = false;
    kagami.enter.enter(root, inputs.USER_NEIGHBOR + sizes.PAGE_SIZE, first.Backing.PA, protection.USER_WRITE) catch |failure| {
        rejected_alias = failure == error.PermissionDenied;
    };
    var rejected_owner = false;
    kagami.enter.enter(other.AddressSpace.?, inputs.USER_ADDRESS, first.Backing.PA, protection.USER_WRITE) catch |failure| {
        rejected_owner = failure == error.PermissionDenied;
    };
    var rejected_protection = false;
    kagami.protect.protect(root, inputs.USER_ADDRESS, protection.USER_READ) catch |failure| {
        rejected_protection = failure == error.PermissionDenied;
    };
    verify.require(rejected_replacement and rejected_alias and rejected_owner and rejected_protection and
        user.state.ledger.find(owner, inputs.USER_ADDRESS) == first and user.state.ledger.find(owner, inputs.USER_NEIGHBOR) == second and
        kagami.extract.extract(root, inputs.USER_ADDRESS).? == first.Backing.PA and
        kagami.extract.extract(root, inputs.USER_NEIGHBOR).? == second.Backing.PA and
        root.ResidentPages == 2 and root.TablePages == tables and other.AddressSpace.?.ResidentPages == 0 and
        std.meta.eql(before, pmm.state.getStatistics()), labels.USER_LEDGER);
}

fn invalidAlias(owner: *Kata) !void {
    const first = user.state.ledger.find(owner, inputs.USER_ADDRESS).?;
    const second = user.state.ledger.find(owner, inputs.USER_NEIGHBOR).?;
    const alias = try kagami.tables.physmap.prepare(owner, inputs.USER_NEIGHBOR);
    const original = alias.*;
    const alias_address = layout.PHYSMAP_BASE + second.Backing.PA;
    defer {
        alias.* = original;
        cpu.control.invalidatePage(alias_address);
    }
    const tables = owner.AddressSpace.?.TablePages;
    const before = pmm.state.getStatistics();
    var destination = [_]u8{inputs.UNCHANGED_BYTE} ** inputs.COPY_BYTES.len;
    alias.Present = false;
    cpu.control.invalidatePage(alias_address);
    var rejected_read = false;
    user.copy.transfer.read(owner, &destination, inputs.CROSS_ADDRESS) catch |failure| {
        rejected_read = failure == error.InvalidPhysmap;
    };
    var rejected_write = false;
    user.copy.transfer.write(owner, inputs.CROSS_ADDRESS, &inputs.COPY_REPLACEMENT) catch |failure| {
        rejected_write = failure == error.InvalidPhysmap;
    };
    var rejected_release = false;
    user.memory.release.releaseAll(owner) catch |failure| {
        rejected_release = failure == error.InvalidPhysmap;
    };
    const preserved = user.state.ledger.find(owner, inputs.USER_ADDRESS) == first and
        user.state.ledger.find(owner, inputs.USER_NEIGHBOR) == second and owner.AddressSpace.?.ResidentPages == 2 and
        owner.AddressSpace.?.TablePages == tables and std.meta.eql(before, pmm.state.getStatistics());
    alias.* = original;
    cpu.control.invalidatePage(alias_address);
    verify.require(rejected_read and rejected_write and std.mem.allEqual(u8, &destination, inputs.UNCHANGED_BYTE), labels.USER_ALIAS);
    verify.require(rejected_release and preserved, labels.USER_PREFLIGHT);
    try user.copy.transfer.read(owner, &destination, inputs.CROSS_ADDRESS);
    verify.require(std.mem.eql(u8, &destination, &inputs.COPY_BYTES) and
        user.copy.transfer.validate(owner, inputs.CROSS_ADDRESS, destination.len, true), labels.USER_ALIAS_RESTORE);
}

fn referenceRestriction(owner: *Kata) void {
    const root = owner.AddressSpace.?;
    kagami.destroy.reference(root);
    defer _ = root.decrementReference();
    const before = pmm.state.getStatistics();
    var rejected = false;
    user.memory.release.releaseAll(owner) catch |failure| {
        rejected = failure == error.OwnerInUse;
    };
    verify.require(rejected and root.ReferenceCount == 2 and root.ResidentPages == 2 and
        user.state.ledger.find(owner, inputs.USER_ADDRESS) != null and user.state.ledger.find(owner, inputs.USER_NEIGHBOR) != null and
        std.meta.eql(before, pmm.state.getStatistics()), labels.USER_IN_USE);
}

fn sealedBoundary(owner: *Kata) !void {
    try user.memory.finalize.finalize(owner, inputs.USER_NEIGHBOR, .ReadOnly);
    const record = user.state.ledger.find(owner, inputs.USER_NEIGHBOR).?;
    const alias = user.state.checks.lookupAlias(record).?;
    const mapping = user.state.checks.lookupOwned(record).?;
    verify.require(!alias.Writable and !alias.Executable and alias.PageSize == sizes.PAGE_SIZE and
        !mapping.Writable and !mapping.Executable, labels.USER_READONLY);
    var rejected_write = false;
    user.copy.transfer.write(owner, inputs.CROSS_ADDRESS, &inputs.COPY_REPLACEMENT) catch |failure| {
        rejected_write = failure == error.SealedPage;
    };
    var rejected_load = false;
    user.memory.load.load(owner, inputs.CROSS_ADDRESS, &inputs.COPY_REPLACEMENT) catch |failure| {
        rejected_load = failure == error.SealedPage;
    };
    var copied: [inputs.COPY_BYTES.len]u8 = undefined;
    try user.copy.transfer.read(owner, &copied, inputs.CROSS_ADDRESS);
    verify.require(rejected_write and rejected_load and std.mem.eql(u8, &copied, &inputs.COPY_BYTES) and
        user.copy.transfer.validate(owner, inputs.CROSS_ADDRESS, copied.len, false) and
        !user.copy.transfer.validate(owner, inputs.CROSS_ADDRESS, copied.len, true), labels.USER_SEALED);
}

fn release(owner: *Kata, baseline: pmm.types.statistics.Statistics, baseline_kernel_tables: u64) !void {
    const physical = [_]u64{
        user.state.ledger.find(owner, inputs.USER_ADDRESS).?.Backing.PA,
        user.state.ledger.find(owner, inputs.USER_NEIGHBOR).?.Backing.PA,
    };
    const root = owner.AddressSpace.?;
    const kernel_tables = kagami.state.getKernelKagami().TablePages;
    const retained_tables = kernel_tables - baseline_kernel_tables;
    try user.memory.release.releaseAll(owner);
    verify.require(root.ResidentPages == 0 and root.WiredPages == 0 and root.TablePages == 1 and
        user.state.ledger.find(owner, inputs.USER_ADDRESS) == null and user.state.ledger.find(owner, inputs.USER_NEIGHBOR) == null and
        !kagami.extract.isMapped(root, inputs.USER_ADDRESS) and !kagami.extract.isMapped(root, inputs.USER_NEIGHBOR), labels.USER_RELEASE);
    for (physical) |frame| {
        const alias = kagami.extract.lookup(kagami.state.getKernelKagami(), layout.PHYSMAP_BASE + frame).?;
        verify.require(!user.state.ledger.ownsPhysical(frame) and
            pmm.state.getRole(frame) == .Free and
            alias.PhysicalAddress == frame and alias.Writable and !alias.Executable and !alias.UserAccessible, labels.USER_RELEASE);
    }
    const after = pmm.state.getStatistics();
    verify.require(after.FreePages + retained_tables == baseline.FreePages and
        after.UsedPages == baseline.UsedPages + retained_tables and after.ReservedPages == baseline.ReservedPages and
        after.MetadataPages == baseline.MetadataPages and after.MetadataBytes == baseline.MetadataBytes and
        kagami.state.getKernelKagami().TablePages == kernel_tables, labels.USER_RELEASE_COUNTS);
    try user.memory.release.releaseAll(owner);
    verify.require(std.meta.eql(after, pmm.state.getStatistics()), labels.USER_RELEASE_COUNTS);
}
