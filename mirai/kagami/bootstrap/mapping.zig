//! Pending Root Table Construction

const common = @import("common");
const constants = @import("mirai").kagami.constants;
const errors = @import("mirai").kagami.errors.bootstrap;
const pmm = @import("mirai").pmm;
const types = @import("mirai").kagami.types;

const indices = common.constants.paging.indices;
const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const Entry = types.entry.Entry;
const PreparedRoot = types.prepared.PreparedRoot;
const Table = types.table.Table;

pub fn allocateTable(prepared: *PreparedRoot) errors.BootError!u64 {
    if (prepared.Phase != .Preparing) return errors.BootError.BootstrapBusy;
    if (prepared.TableCount == prepared.TableFrames.len) return errors.BootError.TableLedgerExhausted;
    const physical_address = try allocateFrame(prepared);
    prepared.TableFrames[prepared.TableCount] = physical_address;
    prepared.TableCount += 1;
    prepared.Kagami.TablePages += 1;
    return physical_address;
}

pub fn allocateStack(prepared: *PreparedRoot) errors.BootError!u64 {
    if (prepared.Phase != .Preparing) return errors.BootError.BootstrapBusy;
    if (prepared.StackCount == prepared.StackFrames.len) return errors.BootError.StackLedgerExhausted;
    const physical_address = try allocateFrame(prepared);
    prepared.StackFrames[prepared.StackCount] = physical_address;
    prepared.StackCount += 1;
    return physical_address;
}

fn allocateFrame(prepared: *const PreparedRoot) errors.BootError!u64 {
    const physical_address = try pmm.allocate.single.allocatePage();
    if (physical_address == 0 or (physical_address & sizes.PAGE_MASK) != 0 or
        physical_address >= prepared.Policy.PhysmapSize or
        sizes.PAGE_SIZE > prepared.Policy.PhysmapSize - physical_address)
    {
        pmm.free.single.freePage(physical_address);
        return errors.BootError.InvalidBootInfo;
    }
    const bytes: [*]u8 = @ptrFromInt(prepared.Policy.PhysmapBase + physical_address);
    @memset(bytes[0..sizes.PAGE_SIZE], 0);
    return physical_address;
}

pub fn table(prepared: *const PreparedRoot, physical_address: u64) *Table {
    return @ptrFromInt(prepared.Policy.PhysmapBase + physical_address);
}

pub fn initializeUpperHalf(prepared: *PreparedRoot) errors.BootError!void {
    prepared.Kagami.PML4Physical = try allocateTable(prepared);
    const root = table(prepared, prepared.Kagami.PML4Physical);
    var index: usize = constants.tables.KERNEL_PML4_START;
    while (index < sizes.ENTRIES_PER_PAGE_TABLE) : (index += 1) {
        _ = try child(prepared, &root.Entries[index]);
    }
}

fn child(prepared: *PreparedRoot, entry: *Entry) errors.BootError!*Table {
    if (entry.Present) {
        if (entry.HugePage or !entry.isOwnedTable()) return errors.BootError.HugeMappingConflict;
        const physical_address = entry.getPhysicalAddress();
        for (prepared.TableFrames[0..prepared.TableCount]) |owned_frame| {
            if (owned_frame == physical_address) return table(prepared, physical_address);
        }
        return errors.BootError.PermissionDenied;
    }
    const physical_address = try allocateTable(prepared);
    entry.* = .{ .Present = true, .Writable = true, .AvailableLow = constants.ownership.OWNED_TABLE };
    entry.setPhysicalAddress(physical_address);
    return table(prepared, physical_address);
}

pub fn map(prepared: *PreparedRoot, virtual_address: u64, physical_address: u64, page_size: u64, writable: bool, executable: bool, uncached: bool) errors.BootError!void {
    if (prepared.Phase != .Preparing) return errors.BootError.BootstrapBusy;
    if (page_size != sizes.PAGE_SIZE and page_size != sizes.LARGE_PAGE_SIZE and page_size != sizes.HUGE_PAGE_SIZE) return errors.BootError.InvalidSize;
    if (virtual_address < ~layout.USER_SPACE_END or (writable and executable)) return errors.BootError.PermissionDenied;
    if ((virtual_address & (page_size - 1)) != 0 or (physical_address & (page_size - 1)) != 0 or
        physical_address >= prepared.Policy.PhysmapSize or page_size > prepared.Policy.PhysmapSize - physical_address)
    {
        return errors.BootError.InvalidAddress;
    }
    const root = table(prepared, prepared.Kagami.PML4Physical);
    const directory = try child(prepared, &root.Entries[tableIndex(virtual_address, indices.PML4_SHIFT)]);
    var target = &directory.Entries[tableIndex(virtual_address, indices.PDPT_SHIFT)];
    if (page_size != sizes.HUGE_PAGE_SIZE) {
        const middle = try child(prepared, target);
        target = &middle.Entries[tableIndex(virtual_address, indices.PD_SHIFT)];
        if (page_size != sizes.LARGE_PAGE_SIZE) {
            if (page_size != sizes.PAGE_SIZE) return errors.BootError.InvalidSize;
            const leaf = try child(prepared, target);
            target = &leaf.Entries[tableIndex(virtual_address, indices.PT_SHIFT)];
        }
    }
    if (target.Present) return errors.BootError.AlreadyMapped;
    target.* = .{
        .Present = true,
        .Writable = writable,
        .WriteThrough = uncached,
        .CacheDisabled = uncached,
        .HugePage = page_size != sizes.PAGE_SIZE,
        .Global = true,
        .AvailableLow = constants.ownership.WIRED,
        .NoExecute = !executable,
    };
    target.setPhysicalAddress(physical_address);
    prepared.Kagami.ResidentPages += page_size / sizes.PAGE_SIZE;
    prepared.Kagami.WiredPages += page_size / sizes.PAGE_SIZE;
}

fn tableIndex(virtual_address: u64, shift: u6) usize {
    return @intCast((virtual_address >> shift) & indices.INDEX_MASK);
}
