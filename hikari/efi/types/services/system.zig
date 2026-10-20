//! Hikari EFI System Table

const boot = @import("hikari").efi.types.services.boot;
const input = @import("hikari").efi.types.protocols.input;
const output = @import("hikari").efi.types.protocols.output;
const runtime = @import("hikari").efi.types.services.runtime;
const types = @import("hikari").efi.types;

pub const SystemTable = extern struct {
    Header: types.table.TableHeader,
    FirmwareVendor: [*:0]const types.base.Char16,
    FirmwareRevision: u32,
    ConsoleInputHandle: types.base.Handle,
    ConsoleInput: *input.SimpleTextInputProtocol,
    ConsoleOutputHandle: types.base.Handle,
    ConsoleOutput: *output.SimpleTextOutputProtocol,
    StandardErrorHandle: types.base.Handle,
    StandardError: *output.SimpleTextOutputProtocol,
    RuntimeServices: *runtime.RuntimeServices,
    BootServices: *boot.BootServices,
    NumberOfTableEntries: usize,
    ConfigurationTable: [*]types.table.ConfigurationTableEntry,
};
