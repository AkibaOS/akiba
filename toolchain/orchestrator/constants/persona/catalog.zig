//! First Party Persona Binary Declarations

const afs = @import("../../../../shared/afs/strings/install.zig");
const ahci = @import("../../../../shared/ahci/strings/install.zig");
const display = @import("../../../../shared/display/strings/install.zig");
const keyboard = @import("../../../../shared/keyboard/strings/install.zig");
const names = @import("../../strings/names.zig");
const paths = @import("../../strings/paths.zig");
const pulse = @import("../../../../shared/pulse/strings/install.zig");

const Definition = @import("../../types/persona/definition.zig").Definition;

pub const BINARIES = .{
    .Weaver = Definition{ .Name = names.MODULE_WEAVER, .Root = paths.WEAVER_ROOT, .Entry = paths.WEAVER_ENTRY, .Profile = .Fixed, .Linker = paths.WEAVER_LINKER },
    .Ahci = Definition{ .Name = names.EXECUTABLE_AHCI, .Root = paths.AHCI_ROOT, .Entry = paths.AHCI_ENTRY, .Profile = .Fixed, .Linker = paths.AHCI_LINKER, .Install = ahci.PATH },
    .Afs = Definition{ .Name = names.EXECUTABLE_AFS, .Root = paths.AFS_ROOT, .Entry = paths.AFS_ENTRY, .Profile = .Fixed, .Linker = paths.AFS_LINKER, .Install = afs.PATH },
    .Pulse = Definition{ .Name = names.EXECUTABLE_PULSE, .Root = paths.PULSE_ROOT, .Entry = paths.PULSE_ENTRY, .Profile = .Pulse, .Linker = paths.PULSE_LINKER, .Install = pulse.PATH },
    .Keyboard = Definition{ .Name = names.EXECUTABLE_KEYBOARD, .Root = paths.KEYBOARD_ROOT, .Entry = paths.KEYBOARD_ENTRY, .Install = keyboard.PATH },
    .Display = Definition{ .Name = names.EXECUTABLE_DISPLAY, .Root = paths.DISPLAY_ROOT, .Entry = paths.DISPLAY_ENTRY, .Install = display.PATH },
};
