//! Hikari Page Table Setup

const std = @import("std");

const address = @import("utils").address;
const common = @import("common");
const constants = @import("hikari").paging.constants;
const control = @import("asm").cpu.control;
const cpuid = @import("asm").cpu.cpuid;
const efi = @import("hikari").efi;
const errors = @import("hikari").paging.errors;
const math = @import("utils").math;
const msr = @import("asm").cpu.msr;
const registers = @import("asm").cpu.constants.control;
const types = @import("hikari").paging.types;

const flags = common.constants.paging.flags;
const indices = common.constants.paging.indices;
const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const SetupError = errors.setup.SetupError;

pub const PageTableSetup = struct {
    BootServices: *efi.types.services.boot.BootServices,
    L4: *types.table.TableL4,
    AllocatedTables: [constants.limits.MAX_ALLOCATED_TABLES]*types.table.PageTable,
    AllocatedCount: usize,
    PhysmapL3: ?*types.table.TableL3,
    PhysmapLimit: u64,
    PhysmapSize: u64,
    PhysicalLimit: u64,
    SupportsGigabytePages: bool,
    RootOwned: bool,

    pub fn initialize(boot_services: *efi.types.services.boot.BootServices) SetupError!PageTableSetup {
        if (!cpuid.supportsNoExecute() or !msr.validateMemoryTypes() or
            (control.readCR4() & (registers.CR4_PCID_ENABLE | registers.CR4_LINEAR_ADDRESS_57_ENABLE)) != 0)
        {
            return SetupError.InvalidMapping;
        }
        const physical_bits = cpuid.physicalAddressBits() orelse return SetupError.InvalidMapping;
        const physical_limit = @as(u64, 1) << @as(u6, @intCast(physical_bits));
        const physmap_limit = @min(layout.PHYSMAP_MAX_SIZE, physical_limit);
        var l4_address: efi.types.base.PhysicalAddress = physmap_limit - 1;
        const status = boot_services.AllocatePages(.MaxAddress, .LoaderData, 1, &l4_address);
        if (efi.status.isError(status)) return SetupError.AllocationFailed;
        if (l4_address == 0 or (l4_address & sizes.PAGE_MASK) != 0 or l4_address > physmap_limit - sizes.PAGE_SIZE) {
            _ = boot_services.FreePages(l4_address, 1);
            return SetupError.AllocationFailed;
        }
        const l4: *types.table.TableL4 = @ptrFromInt(l4_address);
        l4.clear();

        return .{
            .BootServices = boot_services,
            .L4 = l4,
            .AllocatedTables = undefined,
            .AllocatedCount = 0,
            .PhysmapL3 = null,
            .PhysmapLimit = physmap_limit,
            .PhysmapSize = 0,
            .PhysicalLimit = physical_limit,
            .SupportsGigabytePages = cpuid.supportsGigabytePages(),
            .RootOwned = true,
        };
    }

    pub fn deinitialize(self: *PageTableSetup) void {
        if (!self.RootOwned) return;
        self.RootOwned = false;
        while (self.AllocatedCount != 0) {
            self.AllocatedCount -= 1;
            _ = self.BootServices.FreePages(@intFromPtr(self.AllocatedTables[self.AllocatedCount]), 1);
        }
        _ = self.BootServices.FreePages(@intFromPtr(self.L4), 1);
        self.PhysmapL3 = null;
        self.PhysmapSize = 0;
    }

    pub fn allocateTable(self: *PageTableSetup) SetupError!*types.table.PageTable {
        if (!self.RootOwned or self.AllocatedCount == constants.limits.MAX_ALLOCATED_TABLES) {
            return SetupError.AllocationFailed;
        }
        var table_address: efi.types.base.PhysicalAddress = self.PhysmapLimit - 1;
        const status = self.BootServices.AllocatePages(.MaxAddress, .LoaderData, 1, &table_address);
        if (efi.status.isError(status)) return SetupError.AllocationFailed;
        if (table_address == 0 or (table_address & sizes.PAGE_MASK) != 0 or table_address > self.PhysmapLimit - sizes.PAGE_SIZE) {
            _ = self.BootServices.FreePages(table_address, 1);
            return SetupError.AllocationFailed;
        }
        const table: *types.table.PageTable = @ptrFromInt(table_address);
        table.clear();
        self.AllocatedTables[self.AllocatedCount] = table;
        self.AllocatedCount += 1;
        return table;
    }

    pub fn mapIdentity(self: *PageTableSetup, start: u64, size: u64) SetupError!void {
        try self.mapRange(start, start, size, flags.PRESENT | flags.WRITABLE);
    }

    pub fn mapKernel(self: *PageTableSetup, virtual: u64, physical: u64, size: u64) SetupError!void {
        try self.mapKernelSegment(virtual, physical, size, false, true);
    }

    pub fn mapKernelSegment(self: *PageTableSetup, virtual: u64, physical: u64, size: u64, writable: bool, executable: bool) SetupError!void {
        if (virtual < layout.KERNEL_BASE or (writable and executable)) return SetupError.InvalidMapping;
        var page_flags = flags.PRESENT | flags.GLOBAL;
        if (writable) page_flags |= flags.WRITABLE;
        if (!executable) page_flags |= flags.NO_EXECUTE;
        try self.mapRange(virtual, physical, size, page_flags);
    }

    pub fn mapPhysmap(self: *PageTableSetup) SetupError!void {
        if (!self.RootOwned or self.PhysmapL3 != null or
            self.L4.getEntry(constants.indices.PML4_INDEX_PHYSMAP).isPresent())
        {
            return SetupError.InvalidMapping;
        }
        try self.mapRange(layout.PHYSMAP_BASE, 0, self.PhysmapLimit, flags.KERNEL_READ_WRITE_NO_EXECUTE);
        self.PhysmapL3 = @ptrFromInt(self.L4.getEntry(constants.indices.PML4_INDEX_PHYSMAP).getAddress());
        self.PhysmapSize = self.PhysmapLimit;
    }

    pub fn mapFramebuffer(self: *PageTableSetup, base: u64, size: u64) SetupError!void {
        if (base == 0 or size == 0 or base >= self.PhysmapSize or size > self.PhysmapSize - base) {
            return SetupError.InvalidMapping;
        }
        const start = math.integer.alignDown(base, sizes.LARGE_PAGE_SIZE);
        const end = math.integer.alignUp(base + size, sizes.LARGE_PAGE_SIZE);
        if (end > self.PhysmapSize) return SetupError.InvalidMapping;
        try self.modifyAlias(start, start, end - start, .Framebuffer, false);
        try self.modifyAlias(layout.PHYSMAP_BASE + start, start, end - start, .Framebuffer, true);
    }

    pub fn protectKernelAliases(self: *PageTableSetup, physical: u64, size: u64, writable: bool) SetupError!void {
        if (size == 0) return;
        if (physical >= self.PhysmapSize or size > self.PhysmapSize - physical) return SetupError.InvalidMapping;
        const mode: types.mapping.AliasMode = if (writable) .KernelReadWrite else .KernelReadOnly;
        try self.modifyAlias(layout.PHYSMAP_BASE + physical, physical, size, mode, true);
        try self.modifyAlias(physical, physical, size, mode, false);
    }

    pub fn mapRange(self: *PageTableSetup, virtual: u64, physical: u64, size: u64, page_flags: u64) SetupError!void {
        if ((page_flags & flags.PRESENT) == 0 or (page_flags & ~constants.entries.MAPPING_FLAGS) != 0) {
            return SetupError.InvalidMapping;
        }
        var remaining = try self.validateRange(virtual, physical, size);
        var virtual_address = math.integer.alignDown(virtual, sizes.PAGE_SIZE);
        var physical_address = math.integer.alignDown(physical, sizes.PAGE_SIZE);
        while (remaining != 0) {
            const mapped_size = try self.mapLeaf(virtual_address, physical_address, remaining, page_flags);
            remaining -= mapped_size;
            if (remaining != 0) {
                virtual_address += mapped_size;
                physical_address += mapped_size;
            }
        }
    }

    pub fn getL4Address(self: *PageTableSetup) u64 {
        return if (self.RootOwned) @intFromPtr(self.L4) else 0;
    }

    fn validateRange(self: *PageTableSetup, virtual: u64, physical: u64, size: u64) SetupError!u64 {
        if (!self.RootOwned or (virtual & sizes.PAGE_MASK) != (physical & sizes.PAGE_MASK)) {
            return SetupError.InvalidMapping;
        }
        if (size == 0) return 0;
        if (size - 1 > std.math.maxInt(u64) - virtual or
            physical >= self.PhysicalLimit or size > self.PhysicalLimit - physical)
        {
            return SetupError.InvalidMapping;
        }
        const virtual_last = virtual + size - 1;
        if (!((virtual <= constants.limits.CANONICAL_LOW_MAX and virtual_last <= constants.limits.CANONICAL_LOW_MAX) or
            (virtual >= constants.limits.CANONICAL_HIGH_MIN and virtual_last >= constants.limits.CANONICAL_HIGH_MIN)))
        {
            return SetupError.InvalidMapping;
        }
        return math.integer.alignDown(physical + size - 1, sizes.PAGE_SIZE) -
            math.integer.alignDown(physical, sizes.PAGE_SIZE) + sizes.PAGE_SIZE;
    }

    fn getChildTable(self: *PageTableSetup, parent: *types.entry.PageTableEntry) SetupError!*types.table.PageTable {
        if (parent.isPresent()) {
            if (parent.isHuge()) return SetupError.InvalidMapping;
            return @ptrFromInt(parent.getAddress());
        }
        const child = try self.allocateTable();
        parent.* = types.entry.PageTableEntry.fromAddress(@intFromPtr(child), flags.KERNEL_TABLE_FLAGS);
        return child;
    }

    fn mapLeaf(self: *PageTableSetup, virtual: u64, physical: u64, remaining: u64, page_flags: u64) SetupError!u64 {
        const l3 = try self.getChildTable(self.L4.getEntry(address.decompose.extractPML4Index(virtual)));
        const l3_entry = l3.getEntry(address.decompose.extractPDPTIndex(virtual));
        if (l3_entry.isPresent() and l3_entry.isHuge()) {
            return matchingSpan(l3_entry, virtual, physical, remaining, page_flags, sizes.HUGE_PAGE_SIZE);
        }
        if (!l3_entry.isPresent() and self.SupportsGigabytePages and remaining >= sizes.HUGE_PAGE_SIZE and
            ((virtual | physical) & sizes.HUGE_PAGE_MASK) == 0)
        {
            l3_entry.* = makeLeaf(physical, page_flags, sizes.HUGE_PAGE_SIZE);
            return sizes.HUGE_PAGE_SIZE;
        }
        const l2 = try self.getChildTable(l3_entry);
        const l2_entry = l2.getEntry(address.decompose.extractPDIndex(virtual));
        if (l2_entry.isPresent() and l2_entry.isHuge()) {
            return matchingSpan(l2_entry, virtual, physical, remaining, page_flags, sizes.LARGE_PAGE_SIZE);
        }
        if (!l2_entry.isPresent() and remaining >= sizes.LARGE_PAGE_SIZE and
            ((virtual | physical) & sizes.LARGE_PAGE_MASK) == 0)
        {
            l2_entry.* = makeLeaf(physical, page_flags, sizes.LARGE_PAGE_SIZE);
            return sizes.LARGE_PAGE_SIZE;
        }
        const l1 = try self.getChildTable(l2_entry);
        const l1_entry = l1.getEntry(address.decompose.extractPTIndex(virtual));
        if (l1_entry.isPresent()) {
            return matchingSpan(l1_entry, virtual, physical, remaining, page_flags, sizes.PAGE_SIZE);
        }
        l1_entry.* = makeLeaf(physical, page_flags, sizes.PAGE_SIZE);
        return sizes.PAGE_SIZE;
    }

    fn makeLeaf(physical: u64, page_flags: u64, leaf_size: u64) types.entry.PageTableEntry {
        if (leaf_size == sizes.PAGE_SIZE) return types.entry.PageTableEntry.fromAddress(physical, page_flags);
        var large_flags = (page_flags & ~flags.PAT_PAGE) | flags.HUGE_PAGE;
        if ((page_flags & flags.PAT_PAGE) != 0) large_flags |= flags.PAT_LARGE;
        return types.entry.PageTableEntry.fromAddress(physical, large_flags);
    }

    fn leafAddress(entry: *const types.entry.PageTableEntry, leaf_size: u64) u64 {
        return entry.getAddress() & ~(leaf_size - 1);
    }

    fn leafFlags(entry: *const types.entry.PageTableEntry, leaf_size: u64) u64 {
        var page_flags = entry.toRaw() & ~indices.ADDRESS_MASK;
        if (leaf_size != sizes.PAGE_SIZE) {
            page_flags &= ~flags.HUGE_PAGE;
            if ((entry.toRaw() & flags.PAT_LARGE) != 0) page_flags |= flags.PAT_PAGE;
        }
        return page_flags;
    }

    fn matchingSpan(entry: *const types.entry.PageTableEntry, virtual: u64, physical: u64, remaining: u64, page_flags: u64, leaf_size: u64) SetupError!u64 {
        const offset = virtual & (leaf_size - 1);
        if (leafAddress(entry, leaf_size) + offset != physical or
            ((leafFlags(entry, leaf_size) ^ page_flags) & ~constants.entries.HARDWARE_STATE_FLAGS) != 0)
        {
            return SetupError.InvalidMapping;
        }
        return @min(remaining, leaf_size - offset);
    }

    fn findLeaf(self: *PageTableSetup, virtual: u64) SetupError!types.mapping.Leaf {
        const l4_entry = self.L4.getEntry(address.decompose.extractPML4Index(virtual));
        if (!l4_entry.isPresent()) return .{ .Entry = l4_entry, .Size = constants.limits.PML4_ENTRY_SIZE };
        if (l4_entry.isHuge()) return SetupError.InvalidMapping;
        const l3: *types.table.TableL3 = @ptrFromInt(l4_entry.getAddress());
        const l3_entry = l3.getEntry(address.decompose.extractPDPTIndex(virtual));
        if (!l3_entry.isPresent() or l3_entry.isHuge()) return .{ .Entry = l3_entry, .Size = sizes.HUGE_PAGE_SIZE };
        const l2: *types.table.TableL2 = @ptrFromInt(l3_entry.getAddress());
        const l2_entry = l2.getEntry(address.decompose.extractPDIndex(virtual));
        if (!l2_entry.isPresent() or l2_entry.isHuge()) return .{ .Entry = l2_entry, .Size = sizes.LARGE_PAGE_SIZE };
        const l1: *types.table.TableL1 = @ptrFromInt(l2_entry.getAddress());
        return .{ .Entry = l1.getEntry(address.decompose.extractPTIndex(virtual)), .Size = sizes.PAGE_SIZE };
    }

    fn splitLeaf(self: *PageTableSetup, leaf: types.mapping.Leaf) SetupError!void {
        if (leaf.Size != sizes.HUGE_PAGE_SIZE and leaf.Size != sizes.LARGE_PAGE_SIZE) return SetupError.InvalidMapping;
        const child = try self.allocateTable();
        const child_size = leaf.Size / sizes.ENTRIES_PER_PAGE_TABLE;
        const physical = leafAddress(leaf.Entry, leaf.Size);
        const page_flags = leafFlags(leaf.Entry, leaf.Size);
        for (&child.Entries, 0..) |*child_entry, index| {
            child_entry.* = makeLeaf(physical + @as(u64, @intCast(index)) * child_size, page_flags, child_size);
        }
        leaf.Entry.* = types.entry.PageTableEntry.fromAddress(@intFromPtr(child), flags.KERNEL_TABLE_FLAGS);
    }

    fn modifyAlias(self: *PageTableSetup, virtual: u64, physical: u64, size: u64, mode: types.mapping.AliasMode, required: bool) SetupError!void {
        var remaining = try self.validateRange(virtual, physical, size);
        var virtual_address = math.integer.alignDown(virtual, sizes.PAGE_SIZE);
        var physical_address = math.integer.alignDown(physical, sizes.PAGE_SIZE);
        while (remaining != 0) {
            const leaf = try self.findLeaf(virtual_address);
            var changed_size = sizes.PAGE_SIZE;
            if (leaf.Entry.isPresent()) {
                if (leafAddress(leaf.Entry, leaf.Size) + (virtual_address & (leaf.Size - 1)) != physical_address) {
                    return SetupError.InvalidMapping;
                }
                if (leaf.Size != sizes.PAGE_SIZE and
                    ((virtual_address & (leaf.Size - 1)) != 0 or remaining < leaf.Size))
                {
                    try self.splitLeaf(leaf);
                    continue;
                }
                var raw = leaf.Entry.toRaw();
                switch (mode) {
                    .KernelReadOnly => raw = (raw & ~flags.WRITABLE) | flags.NO_EXECUTE,
                    .KernelReadWrite => raw |= flags.WRITABLE | flags.NO_EXECUTE,
                    .Framebuffer => {
                        const pat_flag = if (leaf.Size == sizes.PAGE_SIZE) flags.PAT_PAGE else flags.PAT_LARGE;
                        raw = (raw & ~(flags.WRITE_THROUGH | flags.CACHE_DISABLED | pat_flag)) | flags.WRITE_THROUGH | flags.CACHE_DISABLED | flags.NO_EXECUTE;
                    },
                }
                leaf.Entry.* = @bitCast(raw);
                changed_size = leaf.Size;
            } else {
                if (required) return SetupError.InvalidMapping;
                if (mode != .Framebuffer) {
                    changed_size = @min(remaining, leaf.Size - (virtual_address & (leaf.Size - 1)));
                } else {
                    if (leaf.Size >= sizes.LARGE_PAGE_SIZE and remaining >= sizes.LARGE_PAGE_SIZE and
                        ((virtual_address | physical_address) & sizes.LARGE_PAGE_MASK) == 0)
                    {
                        changed_size = sizes.LARGE_PAGE_SIZE;
                    }
                    try self.mapRange(virtual_address, physical_address, changed_size, flags.MMIO_FLAGS);
                }
            }
            remaining -= changed_size;
            if (remaining != 0) {
                virtual_address += changed_size;
                physical_address += changed_size;
            }
        }
    }
};
