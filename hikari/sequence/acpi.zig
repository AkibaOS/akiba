//! Hikari ACPI Table Locator

const efi = @import("../efi/efi.zig");
const boot = @import("../boot/boot.zig");

pub fn find_acpi(system_table: *efi.services.SystemTable) boot.AcpiInfo {
    var index: usize = 0;
    while (index < system_table.number_of_table_entries) : (index += 1) {
        const entry = &system_table.configuration_table[index];

        if (entry.vendor_guid.equals(efi.constants.guids.acpi_20_table)) {
            return boot.AcpiInfo{
                .rsdp_address = @intFromPtr(entry.vendor_table),
                .rsdp_version = 2,
                .reserved = 0,
            };
        }
    }

    index = 0;
    while (index < system_table.number_of_table_entries) : (index += 1) {
        const entry = &system_table.configuration_table[index];

        if (entry.vendor_guid.equals(efi.constants.guids.acpi_10_table)) {
            return boot.AcpiInfo{
                .rsdp_address = @intFromPtr(entry.vendor_table),
                .rsdp_version = 1,
                .reserved = 0,
            };
        }
    }

    return boot.AcpiInfo{
        .rsdp_address = 0,
        .rsdp_version = 0,
        .reserved = 0,
    };
}
