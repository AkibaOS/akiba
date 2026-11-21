//! Opt In Native Mirai Boot Reader Evidence

const std = @import("std");

const boot = @import("mirai").boot.sequence.state;
const config = @import("tests").machine.config;
const fixture = @import("tests").guest.constants.ahci.fixture;
const kernel = @import("mirai").memory.allocator.native;
const names = @import("tests").phase.strings.scenario;
const paths = @import("tests").fixtures.strings.elf.boot;
const pulse = @import("tests").guest.ahci.pulse;
const read = @import("mirai").bootstrap.storage.read;
const verify = @import("tests").guest.support.verify;

const StorageError = @import("mirai").bootstrap.errors.storage.read.StorageError;
const Volume = @import("shared").boot.types.volume.Volume;
const WitnessError = @import("tests").guest.errors.ahci.witness.WitnessError;

const IMAGE = @embedFile("dynamicimage");

pub fn run() !void {
    var flag: [names.PHASE_VALUE.len]u8 = undefined;
    const value = config.readValue(names.AHCI_FILE, &flag, true) orelse return;
    if (!std.mem.eql(u8, value, names.PHASE_VALUE)) return WitnessError.InvalidAhciMode;
    const info = boot.getBootInfo() orelse return WitnessError.AhciBootVolumeMissing;
    const expected = info.Volume orelse return WitnessError.AhciBootVolumeMissing;
    const allocator = kernel.get();
    try expectMissing(expected, allocator);
    const image = try read.unit(expected, .{ .Parents = &paths.PARENTS, .Unit = paths.UNIT }, allocator);
    defer allocator.free(image.Bytes);
    verify.require(true, names.AHCI_CHECK);
    verify.require(true, names.AHCI_VOLUME_CHECK);
    const key: u16 = @bitCast(image.Location.Address);
    verify.require(key == fixture.RELOCATED_ADDRESS and image.Location.Port == fixture.BOOT_PORT, names.AHCI_LOCATION_CHECK);
    verify.require(std.mem.eql(u8, image.Bytes, IMAGE), names.AHCI_IMAGE_CHECK);
    verify.require(try pulse.prove(expected), names.AHCI_PULSE_CHECK);
}

fn expectMissing(volume: Volume, allocator: std.mem.Allocator) !void {
    if (read.unit(volume, .{ .Parents = &paths.PARENTS, .Unit = paths.MISSING }, allocator)) |unexpected| {
        allocator.free(unexpected.Bytes);
        return WitnessError.UnexpectedBootUnit;
    } else |failure| {
        if (failure != StorageError.BootUnitMissing) return failure;
    }
}
