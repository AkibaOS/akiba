//! Opt In Native AHCI Sector Evidence

const std = @import("std");

const ahci = @import("mirai").drivers.ahci;
const config = @import("tests").machine.config;
const names = @import("tests").phase.strings.scenario;
const verify = @import("tests").guest.support.verify;
const wire = @import("shared").ahci.constants.command;

const GPT_SIGNATURE = "EFI PART";
const PRIMARY_HEADER: u64 = 1;
const MIN_HEADER_BYTES = 92;

pub fn run() !void {
    var flag: [names.PHASE_VALUE.len]u8 = undefined;
    const value = config.readValue(names.AHCI_FILE, &flag, true) orelse return;
    if (!std.mem.eql(u8, value, names.PHASE_VALUE)) return error.InvalidAhciMode;
    var sector: [wire.SECTOR_BYTES]u8 = undefined;
    try ahci.readSector(PRIMARY_HEADER, &sector);
    const header_size = std.mem.readInt(u32, sector[12..16], .little);
    const checksum = std.mem.readInt(u32, sector[16..20], .little);
    const current = std.mem.readInt(u64, sector[24..32], .little);
    @memset(sector[16..20], 0);
    verify.require(std.mem.eql(u8, sector[0..GPT_SIGNATURE.len], GPT_SIGNATURE) and current == PRIMARY_HEADER and
        header_size >= MIN_HEADER_BYTES and header_size <= sector.len and std.hash.Crc32.hash(sector[0..header_size]) == checksum, names.AHCI_CHECK);
}
