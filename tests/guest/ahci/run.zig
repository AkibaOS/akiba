//! Opt In Native AHCI Volume And Relocation Evidence

const std = @import("std");

const boot = @import("mirai").boot.sequence.state;
const config = @import("tests").machine.config;
const fixture = @import("tests").guest.constants.ahci.fixture;
const names = @import("tests").phase.strings.scenario;
const selection = @import("tests").guest.ahci.selection;
const verify = @import("tests").guest.support.verify;

const ProbeError = @import("tests").guest.errors.ahci.transfer.ProbeError;

pub fn run() !void {
    var flag: [names.PHASE_VALUE.len]u8 = undefined;
    const value = config.readValue(names.AHCI_FILE, &flag, true) orelse return;
    if (!std.mem.eql(u8, value, names.PHASE_VALUE)) return ProbeError.InvalidAhciMode;
    const info = boot.getBootInfo() orelse return ProbeError.AhciBootVolumeMissing;
    const expected = info.Volume orelse return ProbeError.AhciBootVolumeMissing;
    const location = try selection.locate(expected);
    verify.require(true, names.AHCI_CHECK);
    verify.require(true, names.AHCI_VOLUME_CHECK);
    const key: u16 = @bitCast(location.Address);
    verify.require(key == fixture.RELOCATED_ADDRESS and location.Port == fixture.BOOT_PORT, names.AHCI_LOCATION_CHECK);
}
