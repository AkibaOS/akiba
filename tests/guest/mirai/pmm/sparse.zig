//! Sparse Metadata Dry Run, Emission And Range Regression

const std = @import("std");

const address = @import("utils").address;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const labels = @import("tests").strings.memory;
const pmm = @import("mirai").pmm;
const types = @import("tests").types.memory;
const verify = @import("tests").guest.support.verify;

const sizes = common.constants.memory.sizes;
const Backing = types.SparseBacking;
const Frame = pmm.types.storage.Frame;
const MemoryRegion = pmm.types.region.MemoryRegion;
const Range = pmm.types.storage.Range;
const State = pmm.types.state.State;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const cursor = pmm.state.getState().SearchStart;
    defer pmm.state.getState().SearchStart = cursor;
    var backing: Backing = .{ .Pages = undefined };
    var borrowed: usize = 0;
    defer for (backing.Pages[0..borrowed]) |physical| pmm.free.single.freePage(physical);
    for (&backing.Pages) |*physical| {
        physical.* = try pmm.allocate.single.allocatePage();
        borrowed += 1;
        @memset(bytesAt(physical.*), inputs.UNCHANGED_BYTE);
    }
    const before = pmm.state.getStatistics();
    const memory_map = [_]MemoryRegion{
        region(0, inputs.SPARSE_LOW_PAGES),
        region(inputs.SPARSE_FIRST_PAGE, 1),
        region(inputs.SPARSE_EXCLUDED_PAGE, 1),
        region(inputs.SPARSE_SECOND_PAGE, 1),
        .{ .BaseAddress = inputs.SPARSE_LOADER_PAGE * sizes.PAGE_SIZE, .Length = sizes.PAGE_SIZE, .RegionType = .Reserved },
        region(inputs.SPARSE_HIGH_PAGE, inputs.SPARSE_SPAN_PAGES + 1),
    };
    const clipped_limit = (inputs.SPARSE_HIGH_PAGE + inputs.SPARSE_SPAN_PAGES) * sizes.PAGE_SIZE;
    const exclusions = [_]Range{
        .{ .Start = inputs.SPARSE_EXCLUDED_PAGE, .End = inputs.SPARSE_EXCLUDED_PAGE + 1 },
        .{ .Start = inputs.SPARSE_EXCLUDED_PAGE, .End = inputs.SPARSE_EXCLUDED_PAGE + 1 },
    };
    const planned = pmm.init.plan.analyze(&memory_map, clipped_limit, &exclusions) orelse @panic(labels.PMM_SPARSE_PLAN);
    verify.require(planned.TotalPages == inputs.SPARSE_LOW_PAGES + 3 + inputs.SPARSE_SPAN_PAGES and
        planned.EligiblePages == inputs.SPARSE_SPAN_PAGES + 2 and planned.MetadataPages == 2 and
        planned.PackedBytes == inputs.SPARSE_PACKED_BYTES, labels.PMM_SPARSE_PLAN);
    checkNoTouch(&memory_map, clipped_limit, &backing);
    var local = pmm.init.emission.build(&memory_map, clipped_limit, &exclusions, &backing, mapFrame) orelse
        @panic(labels.PMM_SPARSE_EMIT);
    const access = pmm.storage.access;
    const statistics = local.Statistics;
    const boundary = inputs.SPARSE_HIGH_PAGE + inputs.SPARSE_SPLIT_PAGES;
    const first = frameAt(backing.Pages[0]);
    const second = frameAt(backing.Pages[1]);
    verify.require(backing.Mapped == 2 and first.Header.Next == second and second.Header.Next == null and
        first.Header.EndPage == boundary and second.Header.FirstPage == boundary and
        bytesAt(backing.Pages[1])[sizes.PAGE_SIZE - 1] == inputs.UNCHANGED_BYTE and untouched(backing.Pages[2]) and
        statistics.MetadataPages == 2 and statistics.MetadataBytes == planned.PackedBytes and statistics.UsedPages == 0 and
        statistics.FreePages == inputs.SPARSE_SPAN_PAGES and statistics.ReservedPages == inputs.SPARSE_LOW_PAGES + 3 and
        statistics.TotalPages == planned.TotalPages and access.read(local.Index, 0) == .Reserved and
        access.read(local.Index, inputs.SPARSE_FIRST_PAGE) == .Reserved and
        access.read(local.Index, inputs.SPARSE_SECOND_PAGE) == .Reserved and
        access.read(local.Index, inputs.SPARSE_EXCLUDED_PAGE) == .Reserved and
        access.read(local.Index, inputs.SPARSE_LOADER_PAGE) == .Hole and
        access.read(local.Index, inputs.SPARSE_HIGH_PAGE - 1) == .Hole and
        access.read(local.Index, clipped_limit / sizes.PAGE_SIZE - 1) == .Free and
        access.read(local.Index, clipped_limit / sizes.PAGE_SIZE) == .Hole, labels.PMM_SPARSE_EMIT);
    checkSearchAndRelease(&local, boundary);
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.PMM_SPARSE_RELEASE);
}

fn checkNoTouch(memory_map: []const MemoryRegion, clipped_limit: u64, backing: *Backing) void {
    const excluded = [_]Range{
        .{ .Start = inputs.SPARSE_EXCLUDED_PAGE, .End = inputs.SPARSE_SECOND_PAGE + 1 },
        .{ .Start = inputs.SPARSE_HIGH_PAGE, .End = inputs.SPARSE_HIGH_PAGE + inputs.SPARSE_SPAN_PAGES },
    };
    const reversed = [_]MemoryRegion{ memory_map[2], memory_map[1] };
    const overlapped = [_]MemoryRegion{ region(inputs.SPARSE_FIRST_PAGE, 2), region(inputs.SPARSE_FIRST_PAGE + 1, 1) };
    verify.require(pmm.init.emission.build(memory_map, clipped_limit, &excluded, backing, mapFrame) == null and
        pmm.init.emission.build(&reversed, inputs.SPARSE_LIMIT, &.{}, backing, mapFrame) == null and
        pmm.init.emission.build(&overlapped, inputs.SPARSE_LIMIT, &.{}, backing, mapFrame) == null and
        backing.Mapped == 0, labels.PMM_SPARSE_NO_TOUCH);
    for (backing.Pages) |physical| verify.require(untouched(physical), labels.PMM_SPARSE_NO_TOUCH);
}

fn checkSearchAndRelease(local: *State, boundary: u64) void {
    const access = pmm.storage.access;
    const search = pmm.storage.search;
    const high = inputs.SPARSE_HIGH_PAGE;
    const limit = local.Index.PhysicalPages;
    verify.require(search.find(local.Index, 0, limit, inputs.SPARSE_SPAN_PAGES, 1) == high and
        search.find(local.Index, high + 1, limit, inputs.SPARSE_SPAN_PAGES - inputs.ALIGNMENT_PAGES, inputs.ALIGNMENT_PAGES) ==
            high + inputs.ALIGNMENT_PAGES and
        search.find(local.Index, boundary - 1, limit, 2, 1) == boundary - 1, labels.PMM_SPARSE_SEARCH);
    const before = local.Statistics;
    access.assign(local.Index, .{ .Start = boundary - 1, .End = boundary + 1 }, .Allocated);
    local.Statistics.FreePages -= 2;
    local.Statistics.UsedPages += 2;
    local.SearchStart = boundary + 1;
    const allocated = local.Statistics;
    verify.require(search.find(local.Index, 0, limit, inputs.SPARSE_SPAN_PAGES, 1) == null and
        !pmm.free.range.releaseFrom(local, inputs.SPARSE_FIRST_PAGE * sizes.PAGE_SIZE, 1) and
        !pmm.free.range.releaseFrom(local, inputs.SPARSE_EXCLUDED_PAGE * sizes.PAGE_SIZE, 2) and
        !pmm.free.range.releaseFrom(local, (high - 1) * sizes.PAGE_SIZE, 1) and
        std.meta.eql(local.Statistics, allocated) and local.SearchStart == boundary + 1 and
        access.matches(local.Index, boundary - 1, boundary + 1, .Allocated), labels.PMM_SPARSE_RELEASE);
    verify.require(pmm.free.range.releaseFrom(local, (boundary - 1) * sizes.PAGE_SIZE, 2) and
        std.meta.eql(local.Statistics, before) and local.SearchStart == boundary - 1 and
        access.matches(local.Index, boundary - 1, boundary + 1, .Free), labels.PMM_SPARSE_RELEASE);
}

fn region(start_page: u64, page_count: u64) MemoryRegion {
    return .{ .BaseAddress = start_page * sizes.PAGE_SIZE, .Length = page_count * sizes.PAGE_SIZE, .RegionType = .Available };
}

fn mapFrame(backing: *Backing, synthetic_physical: u64) *Frame {
    const expected = [_]u64{ inputs.SPARSE_FIRST_PAGE, inputs.SPARSE_SECOND_PAGE };
    if (backing.Mapped >= expected.len or synthetic_physical != expected[backing.Mapped] * sizes.PAGE_SIZE)
        @panic(labels.PMM_SPARSE_EMIT);
    const frame = frameAt(backing.Pages[backing.Mapped]);
    backing.Mapped += 1;
    return frame;
}

fn frameAt(physical: u64) *Frame {
    return @ptrFromInt(address.translate.physToVirt(physical));
}

fn bytesAt(physical: u64) []u8 {
    const bytes: [*]u8 = @ptrFromInt(address.translate.physToVirt(physical));
    return bytes[0..sizes.PAGE_SIZE];
}

fn untouched(physical: u64) bool {
    return std.mem.allEqual(u8, bytesAt(physical), inputs.UNCHANGED_BYTE);
}
