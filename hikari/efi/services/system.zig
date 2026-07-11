//! Hikari EFI System Table

const types = @import("../types/types.zig");
const table = @import("../types/table.zig");
const boot = @import("boot.zig");
const runtime = @import("runtime.zig");
const simple_text_input = @import("../protocols/input.zig");
const simple_text_output = @import("../protocols/output.zig");

pub const SystemTable = extern struct {
    header: table.TableHeader,
    firmware_vendor: [*:0]const types.Char16,
    firmware_revision: u32,
    console_input_handle: types.Handle,
    console_input: *simple_text_input.SimpleTextInputProtocol,
    console_output_handle: types.Handle,
    console_output: *simple_text_output.SimpleTextOutputProtocol,
    standard_error_handle: types.Handle,
    standard_error: *simple_text_output.SimpleTextOutputProtocol,
    runtime_services: *runtime.RuntimeServices,
    boot_services: *boot.BootServices,
    number_of_table_entries: usize,
    configuration_table: [*]table.ConfigurationTableEntry,
};
