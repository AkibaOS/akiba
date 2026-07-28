//! Hikari Page Table Setup

const common = @import("common");
const constants = @import("hikari").paging.constants;
const efi = @import("hikari").efi;
const errors = @import("hikari").paging.errors;

const types = @import("hikari").paging.types;

const address = @import("utils").address;
const math = @import("utils").math;

const flags = common.constants.paging.flags;
const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const SetupError = errors.setup.SetupError;

pub const PageTableSetup = struct {
    BootServices: *efi.services.boot.BootServices,
    L4: *types.table.TableL4,
    AllocatedTables: [constants.limits.MAX_ALLOCATED_TABLES]*types.table.PageTable,
    AllocatedCount: usize,

    pub fn initialize(boot_services: *efi.services.boot.BootServices) SetupError!PageTableSetup {
        var l4_address: efi.types.base.PhysicalAddress = 0;
        const status = boot_services.AllocatePages(
            .AnyPages,
            .LoaderData,
            1,
            &l4_address,
        );

        if (efi.types.base.isError(status)) {
            return SetupError.AllocationFailed;
        }

        const l4: *types.table.TableL4 = @ptrFromInt(l4_address);
        l4.clear();

        return PageTableSetup{
            .BootServices = boot_services,
            .L4 = l4,
            .AllocatedTables = undefined,
            .AllocatedCount = 0,
        };
    }

    pub fn allocateTable(self: *PageTableSetup) SetupError!*types.table.PageTable {
        var table_address: efi.types.base.PhysicalAddress = 0;
        const status = self.BootServices.AllocatePages(
            .AnyPages,
            .LoaderData,
            1,
            &table_address,
        );

        if (efi.types.base.isError(status)) {
            return SetupError.AllocationFailed;
        }

        const table: *types.table.PageTable = @ptrFromInt(table_address);
        table.clear();

        if (self.AllocatedCount < constants.limits.MAX_ALLOCATED_TABLES) {
            self.AllocatedTables[self.AllocatedCount] = table;
            self.AllocatedCount += 1;
        }

        return table;
    }

    pub fn mapIdentity(self: *PageTableSetup, start: u64, size: u64) SetupError!void {
        try self.mapRange(start, start, size, flags.PRESENT | flags.WRITABLE);
    }

    pub fn mapKernel(self: *PageTableSetup, physical: u64, size: u64) SetupError!void {
        try self.mapRange(
            layout.KERNEL_BASE,
            physical,
            size,
            flags.PRESENT | flags.WRITABLE | flags.GLOBAL,
        );
    }

    pub fn mapPhysmap(self: *PageTableSetup, max_physical: u64) SetupError!void {
        const l3 = try self.allocateTable();

        const l4_entry = types.entry.PageTableEntry.fromAddress(
            @intFromPtr(l3),
            flags.PRESENT | flags.WRITABLE,
        );
        self.L4.setEntry(constants.indices.PML4_INDEX_PHYSMAP, l4_entry);

        const size_to_map = if (max_physical > layout.PHYSMAP_MAX_SIZE)
            layout.PHYSMAP_MAX_SIZE
        else
            max_physical;

        const gigabyte_count = math.integer.divideCeil(size_to_map, sizes.HUGE_PAGE_SIZE);

        var gigabyte_index: u64 = 0;
        while (gigabyte_index < gigabyte_count and gigabyte_index < sizes.ENTRIES_PER_PAGE_TABLE) : (gigabyte_index += 1) {
            const physical_address = gigabyte_index * sizes.HUGE_PAGE_SIZE;
            const l3_entry = types.entry.PageTableEntry.fromAddress(
                physical_address,
                flags.PRESENT | flags.WRITABLE | flags.HUGE_PAGE | flags.GLOBAL,
            );
            l3.setEntry(@truncate(gigabyte_index), l3_entry);
        }
    }

    pub fn mapRange(self: *PageTableSetup, virtual: u64, physical: u64, size: u64, page_flags: u64) SetupError!void {
        var virt = math.integer.alignDown(virtual, sizes.PAGE_SIZE);
        var phys = math.integer.alignDown(physical, sizes.PAGE_SIZE);
        var remaining = size;

        while (remaining > 0) {
            const l4_index = address.decompose.extractPML4Index(virt);
            var l3: *types.table.TableL3 = undefined;

            if (self.L4.getEntry(l4_index).isPresent()) {
                l3 = @ptrFromInt(self.L4.getEntry(l4_index).getAddress());
            } else {
                l3 = try self.allocateTable();
                const entry = types.entry.PageTableEntry.fromAddress(
                    @intFromPtr(l3),
                    flags.PRESENT | flags.WRITABLE,
                );
                self.L4.setEntry(l4_index, entry);
            }

            const l3_index = address.decompose.extractPDPTIndex(virt);
            var l2: *types.table.TableL2 = undefined;

            if (l3.getEntry(l3_index).isPresent()) {
                if (l3.getEntry(l3_index).isHuge()) {
                    virt += sizes.HUGE_PAGE_SIZE;
                    phys += sizes.HUGE_PAGE_SIZE;
                    if (remaining >= sizes.HUGE_PAGE_SIZE) {
                        remaining -= sizes.HUGE_PAGE_SIZE;
                    } else {
                        remaining = 0;
                    }
                    continue;
                }
                l2 = @ptrFromInt(l3.getEntry(l3_index).getAddress());
            } else {
                l2 = try self.allocateTable();
                const entry = types.entry.PageTableEntry.fromAddress(
                    @intFromPtr(l2),
                    flags.PRESENT | flags.WRITABLE,
                );
                l3.setEntry(l3_index, entry);
            }

            const l2_index = address.decompose.extractPDIndex(virt);

            if (remaining >= sizes.LARGE_PAGE_SIZE and
                (virt & (sizes.LARGE_PAGE_SIZE - 1)) == 0 and
                (phys & (sizes.LARGE_PAGE_SIZE - 1)) == 0)
            {
                const entry = types.entry.PageTableEntry.fromAddress(
                    phys,
                    page_flags | flags.HUGE_PAGE,
                );
                l2.setEntry(l2_index, entry);

                virt += sizes.LARGE_PAGE_SIZE;
                phys += sizes.LARGE_PAGE_SIZE;
                remaining -= sizes.LARGE_PAGE_SIZE;
                continue;
            }

            var l1: *types.table.TableL1 = undefined;

            if (l2.getEntry(l2_index).isPresent()) {
                if (l2.getEntry(l2_index).isHuge()) {
                    virt += sizes.LARGE_PAGE_SIZE;
                    phys += sizes.LARGE_PAGE_SIZE;
                    if (remaining >= sizes.LARGE_PAGE_SIZE) {
                        remaining -= sizes.LARGE_PAGE_SIZE;
                    } else {
                        remaining = 0;
                    }
                    continue;
                }
                l1 = @ptrFromInt(l2.getEntry(l2_index).getAddress());
            } else {
                l1 = try self.allocateTable();
                const entry = types.entry.PageTableEntry.fromAddress(
                    @intFromPtr(l1),
                    flags.PRESENT | flags.WRITABLE,
                );
                l2.setEntry(l2_index, entry);
            }

            const l1_index = address.decompose.extractPTIndex(virt);
            const entry = types.entry.PageTableEntry.fromAddress(phys, page_flags);
            l1.setEntry(l1_index, entry);

            virt += sizes.PAGE_SIZE;
            phys += sizes.PAGE_SIZE;
            if (remaining >= sizes.PAGE_SIZE) {
                remaining -= sizes.PAGE_SIZE;
            } else {
                remaining = 0;
            }
        }
    }

    pub fn getL4Address(self: *PageTableSetup) u64 {
        return @intFromPtr(self.L4);
    }
};
