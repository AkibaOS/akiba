//! Hikari ACPI Table Locator

const boot = @import("shared").boot;
const efi = @import("../../efi/efi.zig");

pub fn findACPI(system_table: *efi.services.system.SystemTable) boot.types.acpi.ACPIInfo {
    var index: usize = 0;
    while (index < system_table.NumberOfTableEntries) : (index += 1) {
        const entry = &system_table.ConfigurationTable[index];

        if (entry.VendorGUID.equals(efi.constants.guids.ACPI_20_TABLE)) {
            return boot.types.acpi.ACPIInfo{
                .RSDPAddress = @intFromPtr(entry.VendorTable),
                .RSDPVersion = 2,
                .Reserved = 0,
            };
        }
    }

    index = 0;
    while (index < system_table.NumberOfTableEntries) : (index += 1) {
        const entry = &system_table.ConfigurationTable[index];

        if (entry.VendorGUID.equals(efi.constants.guids.ACPI_10_TABLE)) {
            return boot.types.acpi.ACPIInfo{
                .RSDPAddress = @intFromPtr(entry.VendorTable),
                .RSDPVersion = 1,
                .Reserved = 0,
            };
        }
    }

    return boot.types.acpi.ACPIInfo{
        .RSDPAddress = 0,
        .RSDPVersion = 0,
        .Reserved = 0,
    };
}
