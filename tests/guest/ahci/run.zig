//! Opt In Native AHCI Sector Evidence

const std = @import("std");

const config = @import("tests").machine.config;
const header = @import("tests").guest.constants.ahci.header;
const names = @import("tests").phase.strings.scenario;
const probe = @import("tests").guest.ahci.probe;
const signatures = @import("tests").guest.strings.ahci.signature;
const verify = @import("tests").guest.support.verify;
const wire = @import("shared").ahci.constants.command.dma;

const ProbeError = @import("tests").guest.errors.ahci.transfer.ProbeError;

pub fn run() !void {
    var flag: [names.PHASE_VALUE.len]u8 = undefined;
    const value = config.readValue(names.AHCI_FILE, &flag, true) orelse return;
    if (!std.mem.eql(u8, value, names.PHASE_VALUE)) return ProbeError.InvalidAhciMode;
    var sector: [wire.SECTOR_BYTES]u8 = undefined;
    try probe.readSector(header.PRIMARY_SECTOR, &sector);
    const header_size = std.mem.readInt(u32, sector[header.SIZE_OFFSET..][0..@sizeOf(u32)], .little);
    const checksum_field = sector[header.CHECKSUM_OFFSET..][0..@sizeOf(u32)];
    const checksum = std.mem.readInt(u32, checksum_field, .little);
    const current = std.mem.readInt(u64, sector[header.CURRENT_OFFSET..][0..@sizeOf(u64)], .little);
    @memset(checksum_field, 0);
    verify.require(std.mem.eql(u8, sector[0..signatures.GPT_SIGNATURE.len], signatures.GPT_SIGNATURE) and current == header.PRIMARY_SECTOR and
        header_size >= header.MIN_BYTES and header_size <= sector.len and std.hash.Crc32.hash(sector[0..header_size]) == checksum, names.AHCI_CHECK);
}
