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
    l4: *types.TableL4,
    allocated_tables: [64]*types.PageTable,
    allocated_count: usize,

    pub fn initialize(boot_services: *efi.services.BootServices) SetupError!PageTableSetup {
        var l4_addr: efi.types.PhysicalAddress = 0;
        const status = boot_services.allocate_pages(
            .any_pages,
            .loader_data,
            1,
            &l4_addr,
        );

        if (efi.types.is_error(status)) {
            return SetupError.allocation_failed;
        }

        const l4: *types.TableL4 = @ptrFromInt(l4_addr);
        l4.clear();

        return PageTableSetup{
            .boot_services = boot_services,
            .l4 = l4,
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
        const l3 = try self.allocate_table();

        const l4_entry = types.PageTableEntry.from_address(
            @intFromPtr(l3),
            constants.flag_present | constants.flag_writable,
        );
        self.l4.set_entry(constants.pml4_index_physmap, l4_entry);

        const size_to_map = if (max_physical > constants.physmap_size)
            constants.physmap_size
        else
            max_physical;

        const gb_count = (size_to_map + constants.huge_page_size_1g - 1) / constants.huge_page_size_1g;

        var i: u64 = 0;
        while (i < gb_count and i < 512) : (i += 1) {
            const physical_addr = i * constants.huge_page_size_1g;
            const l3_entry = types.PageTableEntry.from_address(
                physical_addr,
                constants.flag_present | constants.flag_writable | constants.flag_huge_page | constants.flag_global,
            );
            l3.set_entry(@truncate(i), l3_entry);
        }
    }

    pub fn map_range(self: *PageTableSetup, virtual: u64, physical: u64, size: u64, flags: u64) SetupError!void {
        var virt = virtual & ~@as(u64, constants.page_size - 1);
        var phys = physical & ~@as(u64, constants.page_size - 1);
        var remaining = size;

        while (remaining > 0) {
            const l4_idx = types.get_l4_index(virt);
            var l3: *types.TableL3 = undefined;

            if (self.l4.get_entry(l4_idx).is_present()) {
                l3 = @ptrFromInt(self.l4.get_entry(l4_idx).get_address());
            } else {
                l3 = try self.allocate_table();
                const entry = types.PageTableEntry.from_address(
                    @intFromPtr(l3),
                    constants.flag_present | constants.flag_writable,
                );
                self.l4.set_entry(l4_idx, entry);
            }

            const l3_idx = types.get_l3_index(virt);
            var l2: *types.TableL2 = undefined;

            if (l3.get_entry(l3_idx).is_present()) {
                if (l3.get_entry(l3_idx).is_huge()) {
                    virt += constants.huge_page_size_1g;
                    phys += constants.huge_page_size_1g;
                    if (remaining >= constants.huge_page_size_1g) {
                        remaining -= constants.huge_page_size_1g;
                    } else {
                        remaining = 0;
                    }
                    continue;
                }
                l2 = @ptrFromInt(l3.get_entry(l3_idx).get_address());
            } else {
                l2 = try self.allocate_table();
                const entry = types.PageTableEntry.from_address(
                    @intFromPtr(l2),
                    constants.flag_present | constants.flag_writable,
                );
                l3.set_entry(l3_idx, entry);
            }

            const l2_idx = types.get_l2_index(virt);

            if (remaining >= constants.huge_page_size_2m and
                (virt & (constants.huge_page_size_2m - 1)) == 0 and
                (phys & (constants.huge_page_size_2m - 1)) == 0)
            {
                const entry = types.PageTableEntry.from_address(
                    phys,
                    flags | constants.flag_huge_page,
                );
                l2.set_entry(l2_idx, entry);

                virt += constants.huge_page_size_2m;
                phys += constants.huge_page_size_2m;
                remaining -= constants.huge_page_size_2m;
                continue;
            }

            var l1: *types.TableL1 = undefined;

            if (l2.get_entry(l2_idx).is_present()) {
                if (l2.get_entry(l2_idx).is_huge()) {
                    virt += constants.huge_page_size_2m;
                    phys += constants.huge_page_size_2m;
                    if (remaining >= constants.huge_page_size_2m) {
                        remaining -= constants.huge_page_size_2m;
                    } else {
                        remaining = 0;
                    }
                    continue;
                }
                l1 = @ptrFromInt(l2.get_entry(l2_idx).get_address());
            } else {
                l1 = try self.allocate_table();
                const entry = types.PageTableEntry.from_address(
                    @intFromPtr(l1),
                    constants.flag_present | constants.flag_writable,
                );
                l2.set_entry(l2_idx, entry);
            }

            const l1_idx = types.get_l1_index(virt);
            const entry = types.PageTableEntry.from_address(phys, flags);
            l1.set_entry(l1_idx, entry);

            virt += constants.page_size;
            phys += constants.page_size;
            if (remaining >= constants.page_size) {
                remaining -= constants.page_size;
            } else {
                remaining = 0;
            }
        }
    }

    pub fn get_l4_address(self: *PageTableSetup) u64 {
        return @intFromPtr(self.l4);
    }
};
