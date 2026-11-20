//! Native AHCI PCI Discovery And Unique Selection Regressions

const std = @import("std");

const discovery = @import("shared").ahci.discover;
const types = @import("shared").ahci.types.discover;
const values = @import("tests").fast.constants.ahci.configuration;

const Address = types.configuration.Address;
const Controller = types.controller.Controller;
const Cursor = types.configuration.Cursor;
const Device = @import("tests").fast.types.ahci.configuration.Device;
const Source = types.configuration.Source;
const Trace = @import("tests").fast.types.ahci.configuration.Trace;

pub fn discoversFunctions() !void {
    var trace: Trace = .{ .Devices = &.{
        .{ .Key = values.SINGLE_SLOT, .Class = values.LEGACY_IDE_CLASS },
        .{ .Key = values.GHOST_FUNCTION },
        .{ .Key = values.FIRST_SLOT, .Class = values.BRIDGE_CLASS, .Header = values.BRIDGE_HEADER },
        .{ .Key = values.FIRST_TARGET },
        .{ .Key = values.REMOTE_TARGET },
    } };
    var cursor: Cursor = .{};
    const first = (try discovery.pci.next(source(&trace), &cursor)).?;
    const remote = (try discovery.pci.next(source(&trace), &cursor)).?;
    try std.testing.expectEqual(values.FIRST_TARGET, @as(u16, @bitCast(first.Address)));
    try std.testing.expectEqual(values.REMOTE_TARGET, @as(u16, @bitCast(remote.Address)));
    try std.testing.expectEqual(values.BAR, remote.Bar);
    try std.testing.expectEqual(values.MEMORY_ENABLED, remote.Command);
    try std.testing.expect((try discovery.pci.next(source(&trace), &cursor)) == null);
    try std.testing.expect((try discovery.pci.next(source(&trace), &cursor)) == null);
    try std.testing.expect(!trace.ReadGhost);
}

pub fn refusesResources() !void {
    var devices = [_]Device{.{ .Key = values.REMOTE_TARGET, .Bar = values.IO_BAR }};
    const device = &devices[0];
    var trace: Trace = .{ .Devices = &devices };
    var cursor: Cursor = .{};
    try std.testing.expectError(error.InvalidAhciBar, discovery.pci.next(source(&trace), &cursor));
    device.Bar = values.UNALIGNED_BAR;
    cursor = .{};
    try std.testing.expectError(error.InvalidAhciBar, discovery.pci.next(source(&trace), &cursor));
    device.Bar = values.BAR;
    device.Command = 0;
    cursor = .{};
    try std.testing.expectError(error.InvalidAhciBar, discovery.pci.next(source(&trace), &cursor));
    device.Command = values.MEMORY_ENABLED;
    device.Header = values.WRONG_HEADER;
    cursor = .{};
    try std.testing.expectError(error.InvalidAhciFunction, discovery.pci.next(source(&trace), &cursor));
}

pub fn selectsUniquely() !void {
    var devices = [_]Device{
        .{ .Key = values.SINGLE_SLOT, .Port = values.TARGET_PORT },
        .{ .Key = values.REMOTE_TARGET },
    };
    var trace: Trace = .{ .Devices = &devices };
    const selected = (try discovery.selection.unique(source(&trace), .{ .Context = &trace, .Find = find })).?;
    try std.testing.expectEqual(values.SINGLE_SLOT, @as(u16, @bitCast(selected.Address)));
    try std.testing.expectEqual(values.TARGET_PORT, selected.Port);
    try std.testing.expectEqual(devices.len, trace.Checked);

    trace.Checked = 0;
    devices[1].Port = values.TARGET_PORT;
    try std.testing.expectError(error.AmbiguousBootVolume, discovery.selection.unique(source(&trace), .{ .Context = &trace, .Find = find }));
    try std.testing.expectEqual(devices.len, trace.Checked);

    trace.Checked = 0;
    devices[1].Fails = true;
    try std.testing.expectError(error.EndOfStream, discovery.selection.unique(source(&trace), .{ .Context = &trace, .Find = find }));
    try std.testing.expectEqual(devices.len, trace.Checked);
}

pub fn reinspectsExactly() !void {
    var devices = [_]Device{
        .{ .Key = values.SINGLE_SLOT },
        .{ .Key = values.REMOTE_TARGET },
    };
    var trace: Trace = .{ .Devices = &devices };
    const address: Address = @bitCast(values.SINGLE_SLOT);
    const located = (try discovery.pci.inspect(source(&trace), address)).?;
    try std.testing.expectEqual(values.SINGLE_SLOT, @as(u16, @bitCast(located.Address)));
    devices[0].Class = values.LEGACY_IDE_CLASS;
    try std.testing.expect((try discovery.pci.inspect(source(&trace), address)) == null);
    devices[0].Class = values.AHCI_CLASS;
    devices[0].Bar = values.IO_BAR;
    try std.testing.expectError(error.InvalidAhciBar, discovery.pci.inspect(source(&trace), address));
}

fn source(trace: *Trace) Source {
    return .{ .Context = trace, .Read = read };
}

fn read(context: ?*anyopaque, address: Address, register: u8) u32 {
    const trace: *Trace = @ptrCast(@alignCast(context.?));
    const key: u16 = @bitCast(address);
    if (key == values.GHOST_FUNCTION) trace.ReadGhost = true;
    for (trace.Devices) |device| {
        if (key != device.Key) continue;
        return switch (register) {
            values.IDENTIFIER_OFFSET => values.IDENTIFIER,
            values.COMMAND_OFFSET => device.Command,
            values.CLASS_OFFSET => device.Class,
            values.HEADER_OFFSET => device.Header,
            values.BAR_OFFSET => device.Bar,
            else => values.ABSENT,
        };
    }
    return values.ABSENT;
}

fn find(context: *anyopaque, controller: Controller) !?u8 {
    const trace: *Trace = @ptrCast(@alignCast(context));
    trace.Checked += 1;
    const key: u16 = @bitCast(controller.Address);
    for (trace.Devices) |device| {
        if (key != device.Key) continue;
        if (device.Fails) return error.EndOfStream;
        return device.Port;
    }
    return error.TestUnexpectedResult;
}
