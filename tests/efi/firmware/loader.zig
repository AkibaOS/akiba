//! Firmware Backed ELF Loader Regressions

const std = @import("std");

const abort = @import("hikari").sequence.cleanup;
const base = @import("hikari").efi.types.base;
const claimtypes = @import("hikari").sequence.types.cleanup.claims;
const codes = @import("hikari").efi.constants.status.codes;
const convention = @import("hikari").efi.constants.convention;
const efi = @import("hikari").efi;
const errors = @import("hikari").loader.errors.elf.load;
const fixtures = @import("tests").fixtures.constants.hikari;
const inputs = @import("tests").efi.constants.firmware.loading;
const labels = @import("tests").efi.strings.firmware.loading;
const loader = @import("hikari").loader.elf.loader;
const memory = @import("hikari").efi.types.memory;
const output = @import("tests").efi.firmware.run;
const services = @import("hikari").efi.types.services;
const status = @import("hikari").efi.status;
const types = @import("tests").efi.types.firmware.loading;

var fixture: types.Fixture = undefined;
var active: bool = false;

pub fn run(real: *services.boot.BootServices) !void {
    defer if (!cleanup()) output.fail(labels.CLEANUP_FAILED);
    try rejectBeforeAllocation(real);
    try loadFallback(real);
    try allocationFailure(real);
    try wrongFixedAddress(real);
}

pub fn cleanup() bool {
    if (!active) return true;
    if (fixture.Owned) |allocation| {
        const result = fixture.Real.FreePages(allocation.Address, allocation.Pages);
        if (status.isError(result)) return false;
        fixture.Owned = null;
    }
    active = false;
    return true;
}

fn rejectBeforeAllocation(real: *services.boot.BootServices) !void {
    var wrapped = try begin(real);
    var malformed = fixtures.VALID_ELF;
    malformed[0] ^= 1;
    const rejected = rejects(&wrapped, inputs.PHYSICAL_LIMIT, &malformed, errors.LoadError.InvalidElfHeader) and
        rejects(&wrapped, 0, &fixtures.VALID_ELF, errors.LoadError.UnsupportedImageLayout) and
        rejects(&wrapped, inputs.PAGE_BYTES + 1, &fixtures.VALID_ELF, errors.LoadError.UnsupportedImageLayout) and
        rejects(&wrapped, inputs.PAGE_BYTES, &fixtures.VALID_ELF, errors.LoadError.UnsupportedImageLayout);
    const untouched = fixture.AllocateCalls == 0 and fixture.FreeCalls == 0 and fixture.Owned == null and
        fixture.Created == null and !fixture.ProtocolMismatch;
    const released = cleanup();
    output.require(rejected and untouched and released, labels.REJECTION);
}

fn loadFallback(real: *services.boot.BootServices) !void {
    var wrapped = try begin(real);
    var backing: efi.types.pages.claims.Claim = .{};
    const image = try loader.load(&wrapped, inputs.PHYSICAL_LIMIT, &fixtures.VALID_ELF, &backing);
    const allocation = fixture.Created orelse return errors.LoadError.AllocationFailed;
    const fallback = !backing.Untrusted and backing.Backing != null and backing.Backing.?.Physical == allocation.Address and backing.Backing.?.Pages == allocation.Pages and
        fixture.AllocateCalls == 2 and fixture.FreeCalls == 0 and fixture.Owned != null and
        fixture.Requests[0].AllocateType == .Address and fixture.Requests[0].MemoryType == .LoaderData and
        fixture.Requests[0].Pages == inputs.IMAGE_PAGES and fixture.Requests[0].Address == inputs.PREFERRED_ADDRESS and
        fixture.Requests[1].AllocateType == .MaxAddress and fixture.Requests[1].MemoryType == .LoaderData and
        fixture.Requests[1].Pages == inputs.IMAGE_PAGES and fixture.Requests[1].Address == inputs.PHYSICAL_LIMIT - 1 and
        allocation.Pages == inputs.IMAGE_PAGES and image.BaseAddress == allocation.Address and
        image.BaseAddress != 0 and image.BaseAddress % inputs.PAGE_BYTES == 0 and
        image.EndAddress == allocation.Address + inputs.IMAGE_BYTES and image.EndAddress <= inputs.PHYSICAL_LIMIT and
        image.totalSize() == inputs.IMAGE_BYTES;
    const bytes = @as([*]const u8, @ptrFromInt(allocation.Address))[0..inputs.IMAGE_BYTES];
    const copied = fixture.Dirtied and std.mem.allEqual(u8, bytes[0..inputs.TEXT_END], inputs.TEXT_BYTE) and
        std.mem.allEqual(u8, bytes[inputs.TEXT_END..inputs.READ_ONLY_END], inputs.READ_ONLY_BYTE) and
        std.mem.allEqual(u8, bytes[inputs.READ_ONLY_END..inputs.DATA_END], inputs.DATA_BYTE);
    const zeroed = fixture.Dirtied and std.mem.allEqual(u8, bytes[inputs.DATA_END..inputs.DATA_MEMORY_END], 0) and
        std.mem.allEqual(u8, bytes[inputs.DATA_MEMORY_END..], 0);
    var relocated = image.EntryPoint == inputs.ENTRY_POINT and image.VirtualBase == inputs.VIRTUAL_BASE and
        image.SegmentCount == inputs.SEGMENTS.len;
    if (relocated) {
        for (inputs.SEGMENTS, 0..) |expected, index| {
            const segment = image.Segments[index];
            if (segment.PhysicalAddress != allocation.Address + expected.PhysicalOffset or
                segment.VirtualAddress != expected.VirtualAddress or segment.MemorySize != expected.MemorySize or
                segment.Flags != expected.Flags)
            {
                relocated = false;
                break;
            }
        }
    }
    const relinquished = efi.pages.release(&wrapped, &backing.Backing);
    const release_matches = relinquished and backing.Backing == null and fixture.FreeCalls == 1 and fixture.Owned == null and
        fixture.Freed != null and fixture.Freed.?.Address == allocation.Address and fixture.Freed.?.Pages == inputs.IMAGE_PAGES;
    const matched = !fixture.ProtocolMismatch;
    const released = cleanup();
    output.require(fallback and matched and released, labels.FALLBACK);
    output.require(copied and released, labels.COPY);
    output.require(zeroed and released, labels.ZERO);
    output.require(relocated and released, labels.SEGMENTS);
    output.require(release_matches and matched and released, labels.RELEASE);
}

fn allocationFailure(real: *services.boot.BootServices) !void {
    var wrapped = try begin(real);
    fixture.RejectFallback = true;
    const rejected = rejects(&wrapped, inputs.PHYSICAL_LIMIT, &fixtures.VALID_ELF, errors.LoadError.AllocationFailed);
    const unowned = fixture.AllocateCalls == 2 and fixture.Requests[0].AllocateType == .Address and
        fixture.Requests[1].AllocateType == .MaxAddress and fixture.FreeCalls == 0 and fixture.Owned == null and
        fixture.Created == null and !fixture.Dirtied and !fixture.ProtocolMismatch;
    const released = cleanup();
    output.require(rejected and unowned and released, labels.FAILURE);
}

fn wrongFixedAddress(real: *services.boot.BootServices) !void {
    var wrapped = try begin(real);
    fixture.WrongFixedAddress = true;
    var claims: claimtypes.Claims = .{ .Paging = .{ .BootServices = &wrapped } };
    const rejected = if (loader.load(&wrapped, inputs.PHYSICAL_LIMIT, &fixtures.VALID_ELF, &claims.Image)) |_| false else |failure| failure == error.AllocationFailed;
    const incomplete = !abort.finish(&claims);
    const allocation = fixture.Owned orelse return errors.LoadError.AllocationFailed;
    const bytes = @as([*]const u8, @ptrFromInt(allocation.Address))[0..inputs.IMAGE_BYTES];
    const untouched = rejected and incomplete and claims.Image.Untrusted and claims.Image.Backing == null and
        allocation.Address != inputs.PREFERRED_ADDRESS and fixture.Dirtied and
        std.mem.allEqual(u8, bytes, inputs.DIRTY_BYTE) and fixture.AllocateCalls == 1 and fixture.FreeCalls == 0 and
        !fixture.ProtocolMismatch;
    const released = cleanup();
    output.require(untouched and released, labels.WRONG_FIXED_ADDRESS);
}

fn begin(real: *services.boot.BootServices) !services.boot.BootServices {
    if (!cleanup()) return errors.LoadError.AllocationFailed;
    fixture = .{ .Real = real };
    active = true;
    var wrapped = real.*;
    wrapped.AllocatePages = allocatePages;
    wrapped.FreePages = freePages;
    return wrapped;
}

fn rejects(wrapped: *services.boot.BootServices, physical_limit: u64, data: []const u8, expected: errors.LoadError) bool {
    var backing: efi.types.pages.claims.Claim = .{};
    if (loader.load(wrapped, physical_limit, data, &backing)) |_| return false else |failure| return failure == expected and backing.Backing == null and !backing.Untrusted;
}

fn allocatePages(allocate_type: memory.AllocateType, memory_type: memory.MemoryType, pages: usize, address: *base.PhysicalAddress) callconv(convention.CALLING_CONVENTION) base.Status {
    if (fixture.AllocateCalls == inputs.REQUEST_CAPACITY) {
        fixture.ProtocolMismatch = true;
        return codes.OUT_OF_RESOURCES;
    }
    fixture.Requests[fixture.AllocateCalls] = .{
        .AllocateType = allocate_type,
        .MemoryType = memory_type,
        .Pages = pages,
        .Address = address.*,
    };
    fixture.AllocateCalls += 1;
    if (memory_type != .LoaderData or pages != inputs.IMAGE_PAGES) {
        fixture.ProtocolMismatch = true;
        return codes.INVALID_PARAMETER;
    }
    const substitute = allocate_type == .Address and fixture.WrongFixedAddress;
    if (allocate_type == .Address and !substitute) return codes.NOT_FOUND;
    if ((allocate_type != .MaxAddress and !substitute) or fixture.Owned != null) {
        fixture.ProtocolMismatch = true;
        return codes.INVALID_PARAMETER;
    }
    if (fixture.RejectFallback) return codes.OUT_OF_RESOURCES;
    if (substitute) address.* = inputs.PHYSICAL_LIMIT - 1;
    const result = fixture.Real.AllocatePages(.MaxAddress, memory_type, pages, address);
    if (!status.isError(result)) {
        const allocation = types.PageAllocation{ .Address = address.*, .Pages = pages };
        fixture.Owned = allocation;
        fixture.Created = allocation;
        const bytes: [*]u8 = @ptrFromInt(allocation.Address);
        @memset(bytes[0 .. pages * inputs.PAGE_BYTES], inputs.DIRTY_BYTE);
        fixture.Dirtied = true;
    }
    return result;
}

fn freePages(address: base.PhysicalAddress, pages: usize) callconv(convention.CALLING_CONVENTION) base.Status {
    fixture.FreeCalls += 1;
    fixture.Freed = .{ .Address = address, .Pages = pages };
    const allocation = fixture.Owned orelse {
        fixture.ProtocolMismatch = true;
        return codes.DEVICE_ERROR;
    };
    if (allocation.Address != address or allocation.Pages != pages) {
        fixture.ProtocolMismatch = true;
        return codes.DEVICE_ERROR;
    }
    const result = fixture.Real.FreePages(address, pages);
    if (!status.isError(result)) fixture.Owned = null;
    return result;
}
