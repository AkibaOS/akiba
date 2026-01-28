//! ATA PIO block device driver

const io = @import("../asm/io.zig");
const serial = @import("serial.zig");

pub const SECTOR_SIZE: usize = 512;

const ATA_DATA: u16 = 0x1F0;
const ATA_ERROR: u16 = 0x1F1;
const ATA_SECTOR_COUNT: u16 = 0x1F2;
const ATA_LBA_LOW: u16 = 0x1F3;
const ATA_LBA_MID: u16 = 0x1F4;
const ATA_LBA_HIGH: u16 = 0x1F5;
const ATA_DRIVE_SELECT: u16 = 0x1F6;
const ATA_STATUS: u16 = 0x1F7;
const ATA_COMMAND: u16 = 0x1F7;

const CMD_READ_SECTORS: u8 = 0x20;

const STATUS_BSY: u8 = 0x80;
const STATUS_DRDY: u8 = 0x40;
const STATUS_DRQ: u8 = 0x08;
const STATUS_ERR: u8 = 0x01;

fn wait_ready() void {
    while ((io.read_port_byte(ATA_STATUS) & STATUS_BSY) != 0) {}
}

fn wait_data_ready() bool {
    var timeout: u32 = 0;
    while (timeout < 10000) : (timeout += 1) {
        const status = io.read_port_byte(ATA_STATUS);
        if ((status & STATUS_ERR) != 0) return false;
        if ((status & STATUS_DRQ) != 0) return true;
    }
    return false;
}

pub const BlockDevice = struct {
    disk_id: u8,

    pub fn init() BlockDevice {
        serial.print("Initializing ATA PIO block device...\r\n");
        return BlockDevice{ .disk_id = 0 };
    }

    pub fn read_sector(self: *BlockDevice, lba: u64, buffer: []u8) bool {
        if (buffer.len < SECTOR_SIZE) {
            serial.print("ERROR: Buffer too small for sector\r\n");
            return false;
        }

        wait_ready();

        const drive_bits: u8 = 0xE0 | (self.disk_id << 4) | @as(u8, @truncate((lba >> 24) & 0x0F));
        io.write_port_byte(ATA_DRIVE_SELECT, drive_bits);
        io.write_port_byte(ATA_SECTOR_COUNT, 1);
        io.write_port_byte(ATA_LBA_LOW, @as(u8, @truncate(lba)));
        io.write_port_byte(ATA_LBA_MID, @as(u8, @truncate(lba >> 8)));
        io.write_port_byte(ATA_LBA_HIGH, @as(u8, @truncate(lba >> 16)));
        io.write_port_byte(ATA_COMMAND, CMD_READ_SECTORS);

        if (!wait_data_ready()) {
            serial.print("ERROR: ATA read timeout\r\n");
            return false;
        }

        var i: usize = 0;
        while (i < SECTOR_SIZE) : (i += 2) {
            const word = io.read_port_word(ATA_DATA);
            buffer[i] = @as(u8, @truncate(word));
            buffer[i + 1] = @as(u8, @truncate(word >> 8));
        }

        return true;
    }
};
