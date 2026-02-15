//! ATA PIO block device driver

const ata_const = @import("../../common/constants/ata.zig");
const ata_limits = @import("../../common/limits/ata.zig");
const int = @import("../../utils/types/int.zig");
const io = @import("../../asm/io.zig");
const serial = @import("../serial/serial.zig");

pub const SECTOR_SIZE = ata_limits.SECTOR_SIZE;

fn wait_ready() void {
    while ((io.in_byte(ata_const.PRIMARY_STATUS) & ata_const.STATUS_BSY) != 0) {}
}

fn wait_data_ready() bool {
    var timeout: u32 = 0;
    while (timeout < ata_limits.TIMEOUT_DATA_READY) : (timeout += 1) {
        const status = io.in_byte(ata_const.PRIMARY_STATUS);
        if ((status & ata_const.STATUS_ERR) != 0) return false;
        if ((status & ata_const.STATUS_DRQ) != 0) return true;
    }
    return false;
}

pub const BlockDevice = struct {
    disk_id: u8,

    pub fn init() BlockDevice {
        serial.printf("Initializing ATA PIO block device...\n", .{});
        return BlockDevice{ .disk_id = 0 };
    }

    pub fn read_sector(self: *BlockDevice, lba: u64, buffer: []u8) bool {
        if (buffer.len < SECTOR_SIZE) {
            serial.printf("ERROR: Buffer too small for sector\n", .{});
            return false;
        }

        wait_ready();

        const drive_bits: u8 = 0xE0 | (self.disk_id << 4) | int.u8_of((lba >> 24) & 0x0F);
        io.out_byte(ata_const.PRIMARY_DRIVE_SELECT, drive_bits);
        io.out_byte(ata_const.PRIMARY_SECTOR_COUNT, 1);
        io.out_byte(ata_const.PRIMARY_LBA_LOW, int.u8_of(lba));
        io.out_byte(ata_const.PRIMARY_LBA_MID, int.u8_of(lba >> 8));
        io.out_byte(ata_const.PRIMARY_LBA_HIGH, int.u8_of(lba >> 16));
        io.out_byte(ata_const.PRIMARY_COMMAND, ata_const.CMD_READ_SECTORS);

        if (!wait_data_ready()) {
            serial.printf("ERROR: ATA read timeout\n", .{});
            return false;
        }

        var i: usize = 0;
        while (i < SECTOR_SIZE) : (i += 2) {
            const word = io.in_word(ata_const.PRIMARY_DATA);
            buffer[i] = int.u8_of(word);
            buffer[i + 1] = int.u8_of(word >> 8);
        }

        return true;
    }
};
