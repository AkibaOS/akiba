//! Hikari Page Table Setup

const efi = @import("../efi/efi.zig");
const constants = @import("constants.zig");
const types = @import("types.zig");

pub const SetupError = error{
    allocation_failed,
    invalid_mapping,
};

pub const PageTableSetup = struct {
    boot_services: *efi.services.BootServices,
    pml4: *types.PageMapLevel4,
    allocated_tables: [64]*types.PageTable,
    allocated_count: usize,

    pub fn initialize(boot_services: *efi.services.BootServices) SetupError!PageTableSetup {
        var pml4_addr: efi.types.PhysicalAddress = 0;
        const status = boot_services.allocate_pages(
            .any_pages,
            .loader_data,
            1,
            &pml4_addr,
        );

        if (efi.types.is_error(status)) {
            return SetupError.allocation_failed;
        }

        const pml4: *types.PageMapLevel4 = @ptrFromInt(pml4_addr);
        pml4.clear();

        return PageTableSetup{
            .boot_services = boot_services,
            .pml4 = pml4,
            .allocated_tables = undefined,
            .allocated_count = 0,
        };
    }

    pub fn allocate_table(self: *PageTableSetup) SetupError!*types.PageTable {
        var table_addr: efi.types.PhysicalAddress = 0;
        const status = self.boot_services.allocate_pages(
            .any_pages,
            .loader_data,
            1,
            &table_addr,
        );

        if (efi.types.is_error(status)) {
            return SetupError.allocation_failed;
        }

        const table: *types.PageTable = @ptrFromInt(table_addr);
        table.clear();

        if (self.allocated_count < 64) {
            self.allocated_tables[self.allocated_count] = table;
            self.allocated_count += 1;
        }

        return table;
    }

    pub fn map_identity(self: *PageTableSetup, start: u64, size: u64) SetupError!void {
        try self.map_range(start, start, size, constants.flag_present | constants.flag_writable);
    }

    pub fn map_kernel(self: *PageTableSetup, physical: u64, size: u64) SetupError!void {
        try self.map_range(
            constants.kernel_base,
            physical,
            size,
            constants.flag_present | constants.flag_writable | constants.flag_global,
        );
    }

    pub fn map_physmap(self: *PageTableSetup, max_physical: u64) SetupError!void {
        const pdpt = try self.allocate_table();

        const pml4_entry = types.PageTableEntry.from_address(
            @intFromPtr(pdpt),
            constants.flag_present | constants.flag_writable,
        );
        self.pml4.set_entry(constants.pml4_index_physmap, pml4_entry);

        const size_to_map = if (max_physical > constants.physmap_size)
            constants.physmap_size
        else
            max_physical;

        const gb_count = (size_to_map + constants.huge_page_size_1g - 1) / constants.huge_page_size_1g;

        var i: u64 = 0;
        while (i < gb_count and i < 512) : (i += 1) {
            const physical_addr = i * constants.huge_page_size_1g;
            const pdpt_entry = types.PageTableEntry.from_address(
                physical_addr,
                constants.flag_present | constants.flag_writable | constants.flag_huge_page | constants.flag_global,
            );
            pdpt.set_entry(@truncate(i), pdpt_entry);
        }
    }

    pub fn map_range(self: *PageTableSetup, virtual: u64, physical: u64, size: u64, flags: u64) SetupError!void {
        var virt = virtual & ~@as(u64, constants.page_size - 1);
        var phys = physical & ~@as(u64, constants.page_size - 1);
        var remaining = size;

        while (remaining > 0) {
            const pml4_idx = types.get_pml4_index(virt);
            var pdpt: *types.PageDirectoryPointerTable = undefined;

            if (self.pml4.get_entry(pml4_idx).is_present()) {
                pdpt = @ptrFromInt(self.pml4.get_entry(pml4_idx).get_address());
            } else {
                pdpt = try self.allocate_table();
                const entry = types.PageTableEntry.from_address(
                    @intFromPtr(pdpt),
                    constants.flag_present | constants.flag_writable,
                );
                self.pml4.set_entry(pml4_idx, entry);
            }

            const pdpt_idx = types.get_pdpt_index(virt);
            var pd: *types.PageDirectory = undefined;

            if (pdpt.get_entry(pdpt_idx).is_present()) {
                if (pdpt.get_entry(pdpt_idx).is_huge()) {
                    virt += constants.huge_page_size_1g;
                    phys += constants.huge_page_size_1g;
                    if (remaining >= constants.huge_page_size_1g) {
                        remaining -= constants.huge_page_size_1g;
                    } else {
                        remaining = 0;
                    }
                    continue;
                }
                pd = @ptrFromInt(pdpt.get_entry(pdpt_idx).get_address());
            } else {
                pd = try self.allocate_table();
                const entry = types.PageTableEntry.from_address(
                    @intFromPtr(pd),
                    constants.flag_present | constants.flag_writable,
                );
                pdpt.set_entry(pdpt_idx, entry);
            }

            const pd_idx = types.get_pd_index(virt);

            if (remaining >= constants.huge_page_size_2m and
                (virt & (constants.huge_page_size_2m - 1)) == 0 and
                (phys & (constants.huge_page_size_2m - 1)) == 0)
            {
                const entry = types.PageTableEntry.from_address(
                    phys,
                    flags | constants.flag_huge_page,
                );
                pd.set_entry(pd_idx, entry);

                virt += constants.huge_page_size_2m;
                phys += constants.huge_page_size_2m;
                remaining -= constants.huge_page_size_2m;
                continue;
            }

            var pt: *types.PageTableLevel1 = undefined;

            if (pd.get_entry(pd_idx).is_present()) {
                if (pd.get_entry(pd_idx).is_huge()) {
                    virt += constants.huge_page_size_2m;
                    phys += constants.huge_page_size_2m;
                    if (remaining >= constants.huge_page_size_2m) {
                        remaining -= constants.huge_page_size_2m;
                    } else {
                        remaining = 0;
                    }
                    continue;
                }
                pt = @ptrFromInt(pd.get_entry(pd_idx).get_address());
            } else {
                pt = try self.allocate_table();
                const entry = types.PageTableEntry.from_address(
                    @intFromPtr(pt),
                    constants.flag_present | constants.flag_writable,
                );
                pd.set_entry(pd_idx, entry);
            }

            const pt_idx = types.get_pt_index(virt);
            const entry = types.PageTableEntry.from_address(phys, flags);
            pt.set_entry(pt_idx, entry);

            virt += constants.page_size;
            phys += constants.page_size;
            if (remaining >= constants.page_size) {
                remaining -= constants.page_size;
            } else {
                remaining = 0;
            }
        }
    }

    pub fn get_pml4_address(self: *PageTableSetup) u64 {
        return @intFromPtr(self.pml4);
    }
};
