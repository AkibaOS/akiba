//! AHCI SATA driver

const ahci_const = @import("../../common/constants/ahci.zig");
const ahci_limits = @import("../../common/limits/ahci.zig");
const ata_const = @import("../../common/constants/ata.zig");
const ata_limits = @import("../../common/limits/ata.zig");
const fis = @import("fis.zig");
const int = @import("../../utils/types/int.zig");
const pci = @import("../pci/pci.zig");
const pci_const = @import("../../common/constants/pci.zig");
const pmm = @import("../../memory/pmm.zig");
const port_ops = @import("port.zig");
const serial = @import("../serial/serial.zig");
const memory_const = @import("../../common/constants/memory.zig");
const types = @import("types.zig");

pub const SECTOR_SIZE = ata_limits.SECTOR_SIZE;

const HIGHER_HALF = memory_const.HIGHER_HALF_START;
const PAGE_SIZE = memory_const.PAGE_SIZE;

var hba_mem: ?*volatile types.HBAMemory = null;
var port_num: u8 = 0;
var dma_buffer_phys: u64 = 0;
var dma_buffer_virt: u64 = 0;

pub fn find_and_init() !void {
    for (pci.get_devices()) |*dev| {
        if (dev.class_code == pci_const.CLASS_MASS_STORAGE and dev.subclass == pci_const.SUBCLASS_SATA) {
            init(dev) catch |err| {
                if (err == error.NoDriveFound) continue;
                return err;
            };
            return;
        }
    }

    return error.NoAHCIController;
}

pub fn init(ahci_device: *pci.Device) !void {
    serial.printf("Initializing AHCI controller at {x}:{x}.{x}\n", .{
        ahci_device.bus,
        ahci_device.device,
        ahci_device.function,
    });

    pci.enable_bus_mastering(ahci_device);
    pci.enable_memory_space(ahci_device);

    const abar_phys = ahci_device.bar5 & ahci_const.BAR_MASK;
    const abar_virt = abar_phys + HIGHER_HALF;

    serial.printf("  ABAR physical: {x}\n", .{abar_phys});

    if (dma_buffer_phys == 0) {
        dma_buffer_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        dma_buffer_virt = dma_buffer_phys + HIGHER_HALF;
    }

    hba_mem = @ptrFromInt(abar_virt);
    const hba = hba_mem.?;

    serial.printf("  AHCI Version: {x}\n", .{hba.vs});

    hba.ghc = hba.ghc | ahci_const.GHC_AE;

    serial.printf("  Ports Implemented: {x}\n", .{hba.pi});

    var found = false;
    var i: u8 = 0;
    while (i < ahci_limits.MAX_PORTS) : (i += 1) {
        if ((hba.pi & (int.u32_of(1) << int.u5_of(i))) != 0) {
            const port = port_ops.get(hba, i);
            if (port_ops.check_type(port) == ahci_const.PORT_TYPE_SATA) {
                serial.printf("  Found SATA drive on port {}\n", .{i});
                port_num = i;

                try rebase_port(port);
                found = true;
                break;
            }
        }
    }

    if (!found) return error.NoDriveFound;
}

fn rebase_port(port: *volatile types.HBAPort) !void {
    port_ops.stop_cmd(port);

    const clb_phys = pmm.alloc_page() orelse return error.OutOfMemory;
    const fb_phys = pmm.alloc_page() orelse return error.OutOfMemory;

    port.clb = clb_phys;
    port.fb = fb_phys;

    const clb_virt = clb_phys + HIGHER_HALF;
    const fb_virt = fb_phys + HIGHER_HALF;

    @memset(@as([*]u8, @ptrFromInt(clb_virt))[0..PAGE_SIZE], 0);
    @memset(@as([*]u8, @ptrFromInt(fb_virt))[0..PAGE_SIZE], 0);

    const cmdheader = @as([*]volatile types.CmdHeader, @ptrFromInt(clb_virt));

    var i: usize = 0;
    while (i < ahci_limits.MAX_CMD_SLOTS) : (i += 1) {
        cmdheader[i].prdtl = 8;

        const cmdtable_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        cmdheader[i].ctba = cmdtable_phys;

        @memset(@as([*]u8, @ptrFromInt(cmdtable_phys + HIGHER_HALF))[0..PAGE_SIZE], 0);
    }

    port.serr = 0xFFFFFFFF;
    port.is = 0xFFFFFFFF;

    port_ops.start_cmd(port);
}

fn do_read_sector(lba: u64, buffer: *[SECTOR_SIZE]u8) bool {
    const hba = hba_mem orelse return false;
    const port = port_ops.get(hba, port_num);

    port.is = 0xFFFFFFFF;

    const slot = port_ops.find_cmd_slot(port) orelse return false;

    const clb_virt = port.clb + HIGHER_HALF;
    const cmdheader = @as([*]volatile types.CmdHeader, @ptrFromInt(clb_virt));

    cmdheader[slot].cfl = @sizeOf(types.FISRegH2D) / 4;
    cmdheader[slot].prdtl = 1;
    cmdheader[slot].prdbc = 0;

    const cmdtbl_virt = cmdheader[slot].ctba + HIGHER_HALF;
    const cmdtbl = @as(*volatile types.CmdTable, @ptrFromInt(cmdtbl_virt));
    @memset(@as([*]u8, @ptrFromInt(cmdtbl_virt))[0..ahci_limits.CMD_TABLE_CLEAR_SIZE], 0);

    cmdtbl.prdt_entry[0].dba = dma_buffer_phys;
    cmdtbl.prdt_entry[0].dbc = (SECTOR_SIZE - 1) | ahci_const.PRDT_INTERRUPT;
    cmdtbl.prdt_entry[0]._rsv0 = 0;

    const cmdfis = @as(*volatile types.FISRegH2D, @ptrCast(&cmdtbl.cfis));
    fis.setup_read(cmdfis, lba);

    var spin: u32 = 0;
    while ((port.tfd & (ata_const.STATUS_BSY | ata_const.STATUS_DRQ)) != 0 and spin < ahci_limits.TIMEOUT_CMD) : (spin += 1) {}
    if (spin == ahci_limits.TIMEOUT_CMD) return false;

    const ci_bit = int.u32_of(1) << int.u5_of(slot);
    port.ci = ci_bit;

    spin = 0;
    while (spin < ahci_limits.TIMEOUT_WAIT) : (spin += 1) {
        if ((port.ci & ci_bit) == 0) break;
        if ((port.is & ahci_const.PxIS_TFES) != 0) return false;
    }

    if ((port.ci & ci_bit) != 0) return false;

    const dma = @as([*]u8, @ptrFromInt(dma_buffer_virt));
    for (buffer, 0..) |*byte, i| {
        byte.* = dma[i];
    }

    return true;
}

fn do_write_sector(lba: u64, buffer: *const [SECTOR_SIZE]u8) bool {
    const hba = hba_mem orelse return false;
    const port = port_ops.get(hba, port_num);

    port.is = 0xFFFFFFFF;

    const slot = port_ops.find_cmd_slot(port) orelse return false;

    const clb_virt = port.clb + HIGHER_HALF;
    const cmdheader = @as([*]volatile types.CmdHeader, @ptrFromInt(clb_virt));

    cmdheader[slot].cfl = @sizeOf(types.FISRegH2D) / 4;
    cmdheader[slot].prdtl = 1;
    cmdheader[slot].prdbc = 0;

    const cmdtbl_virt = cmdheader[slot].ctba + HIGHER_HALF;
    const cmdtbl = @as(*volatile types.CmdTable, @ptrFromInt(cmdtbl_virt));
    @memset(@as([*]u8, @ptrFromInt(cmdtbl_virt))[0..ahci_limits.CMD_TABLE_CLEAR_SIZE], 0);

    const dma = @as([*]u8, @ptrFromInt(dma_buffer_virt));
    for (buffer, 0..) |byte, i| {
        dma[i] = byte;
    }

    cmdtbl.prdt_entry[0].dba = dma_buffer_phys;
    cmdtbl.prdt_entry[0].dbc = (SECTOR_SIZE - 1) | ahci_const.PRDT_INTERRUPT;
    cmdtbl.prdt_entry[0]._rsv0 = 0;

    const cmdfis = @as(*volatile types.FISRegH2D, @ptrCast(&cmdtbl.cfis));
    fis.setup_write(cmdfis, lba);

    var spin: u32 = 0;
    while ((port.tfd & (ata_const.STATUS_BSY | ata_const.STATUS_DRQ)) != 0 and spin < ahci_limits.TIMEOUT_CMD) : (spin += 1) {}
    if (spin == ahci_limits.TIMEOUT_CMD) return false;

    const ci_bit = int.u32_of(1) << int.u5_of(slot);
    port.ci = ci_bit;

    spin = 0;
    while (spin < ahci_limits.TIMEOUT_WAIT) : (spin += 1) {
        if ((port.ci & ci_bit) == 0) break;
        if ((port.is & ahci_const.PxIS_TFES) != 0) return false;
    }

    return (port.ci & ci_bit) == 0;
}

pub const BlockDevice = struct {
    pub fn init() BlockDevice {
        return BlockDevice{};
    }

    pub fn read_sector(self: *BlockDevice, lba: u64, buffer: *[SECTOR_SIZE]u8) bool {
        _ = self;
        return do_read_sector(lba, buffer);
    }

    pub fn write_sector(self: *BlockDevice, lba: u64, buffer: *const [SECTOR_SIZE]u8) bool {
        _ = self;
        return do_write_sector(lba, buffer);
    }
};
