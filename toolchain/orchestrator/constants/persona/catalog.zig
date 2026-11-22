//! First Party Persona Binary Declarations

const installed = @import("../../../../shared/location/strings/installed/paths.zig");
const names = @import("../../strings/names.zig");
const paths = @import("../../strings/paths.zig");

const Definition = @import("../../types/persona/definition.zig").Definition;

pub const BINARIES = .{
    .Weaver = Definition{ .Name = names.MODULE_WEAVER, .Root = paths.WEAVER_ROOT, .Entry = paths.WEAVER_ENTRY, .Profile = .Fixed, .Linker = paths.WEAVER_LINKER },
    .Ahci = Definition{ .Name = names.EXECUTABLE_AHCI, .Root = paths.AHCI_ROOT, .Entry = paths.AHCI_ENTRY, .Profile = .Fixed, .Linker = paths.AHCI_LINKER, .Install = installed.FLAT_AHCI_PATH },
    .Afs = Definition{ .Name = names.EXECUTABLE_AFS, .Root = paths.AFS_ROOT, .Entry = paths.AFS_ENTRY, .Profile = .Fixed, .Linker = paths.AFS_LINKER, .Install = installed.FLAT_AFS_PATH },
    .Pulse = Definition{ .Name = names.EXECUTABLE_PULSE, .Root = paths.PULSE_ROOT, .Entry = paths.PULSE_ENTRY, .Profile = .Pulse, .Linker = paths.PULSE_LINKER, .Install = installed.FLAT_PULSE_PATH },
    .Keyboard = Definition{ .Name = names.EXECUTABLE_KEYBOARD, .Root = paths.KEYBOARD_ROOT, .Entry = paths.KEYBOARD_ENTRY, .Install = installed.FLAT_KEYBOARD_PATH },
    .Display = Definition{ .Name = names.EXECUTABLE_DISPLAY, .Root = paths.DISPLAY_ROOT, .Entry = paths.DISPLAY_ENTRY, .Install = installed.FLAT_DISPLAY_PATH },
};
