//! Opt In Native AHCI Volume Evidence

const std = @import("std");

const config = @import("tests").machine.config;
const names = @import("tests").phase.strings.scenario;
const probe = @import("tests").guest.ahci.probe;
const verify = @import("tests").guest.support.verify;
const volume = @import("tests").guest.ahci.volume;

const ProbeError = @import("tests").guest.errors.ahci.transfer.ProbeError;

pub fn run() !void {
    var flag: [names.PHASE_VALUE.len]u8 = undefined;
    const value = config.readValue(names.AHCI_FILE, &flag, true) orelse return;
    if (!std.mem.eql(u8, value, names.PHASE_VALUE)) return ProbeError.InvalidAhciMode;
    try probe.withDisk(volume.match);
    verify.require(true, names.AHCI_CHECK);
    verify.require(true, names.AHCI_VOLUME_CHECK);
}
