//! AHCI port operations

const ahci_const = @import("../../common/constants/ahci.zig");
const ahci_limits = @import("../../common/limits/ahci.zig");
const ata_const = @import("../../common/constants/ata.zig");
const int = @import("../../utils/types/int.zig");
const types = @import("types.zig");

pub fn get(hba: *volatile types.HBAMemory, index: u8) *volatile types.HBAPort {
    const base = @intFromPtr(hba);
    const offset = ahci_const.PORT_OFFSET_BASE + (int.usize_of(index) * @sizeOf(types.HBAPort));
    return @ptrFromInt(base + offset);
}

pub fn stop_cmd(port: *volatile types.HBAPort) void {
    port.cmd = port.cmd & ~ahci_const.PORT_CMD_ST;
    port.cmd = port.cmd & ~ahci_const.PORT_CMD_FRE;

    var spin: u32 = 0;
    while (spin < ahci_limits.TIMEOUT_SPIN) : (spin += 1) {
        if ((port.cmd & ahci_const.PORT_CMD_FR) != 0) continue;
        if ((port.cmd & ahci_const.PORT_CMD_CR) != 0) continue;
        break;
    }
}

pub fn start_cmd(port: *volatile types.HBAPort) void {
    var spin: u32 = 0;
    while ((port.cmd & ahci_const.PORT_CMD_CR) != 0 and spin < ahci_limits.TIMEOUT_SPIN) : (spin += 1) {}

    port.cmd = port.cmd | ahci_const.PORT_CMD_FRE;
    port.cmd = port.cmd | ahci_const.PORT_CMD_ST;
}

pub fn find_cmd_slot(port: *volatile types.HBAPort) ?u8 {
    const slots = port.sact | port.ci;

    var i: u8 = 0;
    while (i < ahci_limits.MAX_CMD_SLOTS) : (i += 1) {
        if ((slots & (int.u32_of(1) << int.u5_of(i))) == 0) {
            return i;
        }
    }

    return null;
}

pub fn check_type(port: *volatile types.HBAPort) u32 {
    const ssts = port.ssts;
    const ipm = int.u8_of((ssts >> 8) & 0x0F);
    const det = int.u8_of(ssts & 0x0F);

    if (det != ahci_const.SSTS_DET_PRESENT or ipm != ahci_const.SSTS_IPM_ACTIVE) {
        return ahci_const.PORT_TYPE_NONE;
    }

    return switch (port.sig) {
        ata_const.SIG_ATA => ahci_const.PORT_TYPE_SATA,
        ata_const.SIG_ATAPI => ahci_const.PORT_TYPE_ATAPI,
        ata_const.SIG_SEMB => ahci_const.PORT_TYPE_SEMB,
        ata_const.SIG_PM => ahci_const.PORT_TYPE_PM,
        else => ahci_const.PORT_TYPE_NONE,
    };
}
