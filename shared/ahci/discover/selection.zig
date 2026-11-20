//! Require Exactly One Verifiable Native Boot Location

const pci = @import("shared").ahci.discover.pci;
const types = @import("shared").ahci.types.discover;

const Cursor = types.configuration.Cursor;
const Location = types.selection.Location;
const Probe = types.selection.Probe;
const Source = types.configuration.Source;

pub fn unique(source: Source, probe: Probe) anyerror!?Location {
    var cursor: Cursor = .{};
    var selected: ?Location = null;
    while (try pci.next(source, &cursor)) |controller| {
        const port = try probe.Find(probe.Context, controller) orelse continue;
        if (selected != null) return error.AmbiguousBootVolume;
        selected = .{ .Address = controller.Address, .Port = port };
    }
    return selected;
}
