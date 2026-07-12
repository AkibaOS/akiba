//! Hikari EFI System Table

const boot = @import("boot.zig");
const input = @import("../protocols/input.zig");
const output = @import("../protocols/output.zig");
const runtime = @import("runtime.zig");
const types = @import("../types/types.zig");

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
