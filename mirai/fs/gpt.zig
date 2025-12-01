//! GPT (GUID Partition Table) parser

const ahci = @import("../drivers/ahci.zig");
const serial = @import("../drivers/serial.zig");

pub const Partition = struct {
    start_lba: u64,
    end_lba: u64,
    name: [36]u16,
};

pub fn find_first_partition(device: *ahci.BlockDevice) ?Partition {
    var sector: [512]u8 align(16) = undefined;

    if (!device.read_sector(1, &sector)) {
        serial.print("Failed to read GPT header\n");
        return null;
    }

    const signature = sector[0..8];
    const expected = "EFI PART";

    for (signature, 0..) |byte, i| {
        if (byte != expected[i]) {
            serial.print("Invalid GPT signature\n");
            return null;
        }
    }

    const partition_entry_lba = @as(u64, sector[72]) |
        (@as(u64, sector[73]) << 8) |
        (@as(u64, sector[74]) << 16) |
        (@as(u64, sector[75]) << 24) |
        (@as(u64, sector[76]) << 32) |
        (@as(u64, sector[77]) << 40) |
        (@as(u64, sector[78]) << 48) |
        (@as(u64, sector[79]) << 56);

    if (!device.read_sector(partition_entry_lba, &sector)) {
        serial.print("Failed to read partition entry\n");
        return null;
    }

    const start_lba = @as(u64, sector[32]) |
        (@as(u64, sector[33]) << 8) |
        (@as(u64, sector[34]) << 16) |
        (@as(u64, sector[35]) << 24) |
        (@as(u64, sector[36]) << 32) |
        (@as(u64, sector[37]) << 40) |
        (@as(u64, sector[38]) << 48) |
        (@as(u64, sector[39]) << 56);

    const end_lba = @as(u64, sector[40]) |
        (@as(u64, sector[41]) << 8) |
        (@as(u64, sector[42]) << 16) |
        (@as(u64, sector[43]) << 24) |
        (@as(u64, sector[44]) << 32) |
        (@as(u64, sector[45]) << 40) |
        (@as(u64, sector[46]) << 48) |
        (@as(u64, sector[47]) << 56);

    serial.print("GPT: Found partition at LBA ");
    serial.print_hex(start_lba);
    serial.print(" to ");
    serial.print_hex(end_lba);
    serial.print("\n");

    return Partition{
        .start_lba = start_lba,
        .end_lba = end_lba,
        .name = undefined,
    };
}
