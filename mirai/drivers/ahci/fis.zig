//! AHCI FIS utilities

const ahci_const = @import("../../common/constants/ahci.zig");
const ata = @import("../../common/constants/ata.zig");
const int = @import("../../utils/types/int.zig");
const types = @import("types.zig");

pub fn setup_read(fis: *volatile types.FISRegH2D, lba: u64) void {
    fis.fis_type = ahci_const.FIS_TYPE_REG_H2D;
    fis.pmport_c = 0x80;
    fis.command = ata.CMD_READ_DMA_EX;

    fis.lba0 = int.u8_of(lba);
    fis.lba1 = int.u8_of(lba >> 8);
    fis.lba2 = int.u8_of(lba >> 16);
    fis.device = 1 << 6;
    fis.lba3 = int.u8_of(lba >> 24);
    fis.lba4 = int.u8_of(lba >> 32);
    fis.lba5 = int.u8_of(lba >> 40);

    fis.countl = 1;
    fis.counth = 0;
}

pub fn setup_write(fis: *volatile types.FISRegH2D, lba: u64) void {
    fis.fis_type = ahci_const.FIS_TYPE_REG_H2D;
    fis.pmport_c = 0x80;
    fis.command = ata.CMD_WRITE_DMA_EX;

    fis.lba0 = int.u8_of(lba);
    fis.lba1 = int.u8_of(lba >> 8);
    fis.lba2 = int.u8_of(lba >> 16);
    fis.device = 1 << 6;
    fis.lba3 = int.u8_of(lba >> 24);
    fis.lba4 = int.u8_of(lba >> 32);
    fis.lba5 = int.u8_of(lba >> 40);

    fis.countl = 1;
    fis.counth = 0;
}
