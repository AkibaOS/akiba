//! Opt In Native Mirai Boot Reader Evidence

const std = @import("std");

const afs = @import("shared").afs.constants.magic;
const attachment = @import("mirai").device.ahci.attachment;
const boot = @import("mirai").boot.sequence.state;
const config = @import("tests").machine.config;
const discovery = @import("shared").ahci.discover.pci;
const fixture = @import("tests").guest.constants.ahci.fixture;
const kernel = @import("mirai").memory.allocator.native;
const layout = @import("common").constants.memory.layout;
const messages = @import("tests").guest.strings.ahci.storage;
const names = @import("tests").phase.strings.scenario;
const paths = @import("tests").fixtures.strings.elf.boot;
const pci = @import("mirai").device.pci.configuration;
const physmap = @import("mirai").kagami.tables.physmap;
const print = @import("mirai").boot.sequence.print;
const pulse = @import("tests").guest.ahci.pulse;
const read = @import("mirai").bootstrap.storage.read;
const registers = @import("mirai").device.ahci.registers;
const selected = @import("mirai").device.ahci.selected;
const values = @import("mirai").device.constants.ahci.registers;
const verify = @import("tests").guest.support.verify;
const wire = @import("shared").ahci.constants.command.dma;

const Cursor = @import("shared").ahci.types.discover.configuration.Cursor;
const StorageError = @import("mirai").bootstrap.errors.storage.read.StorageError;
const Volume = @import("shared").boot.types.volume.Volume;
const WitnessError = @import("tests").guest.errors.ahci.witness.WitnessError;

const IMAGE = @embedFile("dynamicimage");

pub fn enabled() !bool {
    var flag: [names.PHASE_VALUE.len]u8 = undefined;
    const value = config.readValue(names.AHCI_FILE, &flag, true) orelse return false;
    if (!std.mem.eql(u8, value, names.PHASE_VALUE)) return WitnessError.InvalidAhciMode;
    return true;
}

pub fn run() !void {
    const info = boot.getBootInfo() orelse return WitnessError.AhciBootVolumeMissing;
    const expected = info.Volume orelse return WitnessError.AhciBootVolumeMissing;
    const allocator = kernel.get();
    expectMissing(expected, allocator) catch |failure| {
        try diagnose();
        return failure;
    };
    const image = try read.unit(expected, .{ .Parents = &paths.PARENTS, .Unit = paths.UNIT }, allocator);
    defer allocator.free(image.Bytes);
    verify.require(true, names.AHCI_CHECK);
    verify.require(true, names.AHCI_VOLUME_CHECK);
    const key: u16 = @bitCast(image.Location.Address);
    try attachment.verifyDetached(image.Location);
    var first: [wire.SECTOR_BYTES]u8 = undefined;
    try selected.execute(image.Location, .{ .Read = expected.FirstLBA }, &first);
    try attachment.verifyDetached(image.Location);
    verify.require(key == fixture.RELOCATED_ADDRESS and image.Location.Port == fixture.BOOT_PORT and
        std.mem.readInt(u64, first[0..@sizeOf(u64)], .little) == afs.SIGNATURE, names.AHCI_LOCATION_CHECK);
    verify.require(std.mem.eql(u8, image.Bytes, IMAGE), names.AHCI_IMAGE_CHECK);
    verify.require(try pulse.prove(expected), names.AHCI_PULSE_CHECK);
}

fn diagnose() !void {
    var cursor: Cursor = .{};
    while (try discovery.next(pci.source(), &cursor)) |controller| {
        const alias = try physmap.uncachedDevicePage(controller.Bar);
        defer physmap.restoreDevicePage(alias);
        const aperture = layout.PHYSMAP_BASE + controller.Bar;
        var pending = try registers.ports(aperture);
        while (pending != 0) {
            const index: u5 = @intCast(@ctz(pending));
            pending &= pending - 1;
            const port = aperture + values.PORT_BASE + @as(u64, index) * values.PORT_STRIDE;
            print.log(messages.PORT, .{ @as(u16, @bitCast(controller.Address)), index, registers.read(port, values.LINK), registers.read(port, values.SIGNATURE), registers.read(port, values.COMMAND) });
        }
    }
}

fn expectMissing(volume: Volume, allocator: std.mem.Allocator) !void {
    if (read.unit(volume, .{ .Parents = &paths.PARENTS, .Unit = paths.MISSING }, allocator)) |unexpected| {
        allocator.free(unexpected.Bytes);
        return WitnessError.UnexpectedBootUnit;
    } else |failure| {
        if (failure != StorageError.BootUnitMissing) return failure;
    }
}
