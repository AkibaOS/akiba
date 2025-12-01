//! AHCI (Advanced Host Controller Interface) SATA driver

const serial = @import("serial.zig");
const pci = @import("pci.zig");
const pmm = @import("../memory/pmm.zig");
const paging = @import("../memory/paging.zig");

pub const SECTOR_SIZE = 512;

const HBA_PORT_CMD_ST: u32 = 0x0001;
const HBA_PORT_CMD_FRE: u32 = 0x0010;
const HBA_PORT_CMD_FR: u32 = 0x4000;
const HBA_PORT_CMD_CR: u32 = 0x8000;

const HBA_GHC_AE: u32 = (1 << 31);

const ATA_DEV_BUSY: u8 = 0x80;
const ATA_DEV_DRQ: u8 = 0x08;

const ATA_CMD_READ_DMA_EX: u8 = 0x25;

const FIS_TYPE_REG_H2D: u8 = 0x27;

const HBA_PxIS_TFES: u32 = (1 << 30);

const HBAPort = extern struct {
    clb: u64,
    fb: u64,
    is: u32,
    ie: u32,
    cmd: u32,
    _rsv0: u32,
    tfd: u32,
    sig: u32,
    ssts: u32,
    sctl: u32,
    serr: u32,
    sact: u32,
    ci: u32,
    sntf: u32,
    fbs: u32,
    _rsv1_0: u32,
    _rsv1_1: u32,
    _rsv1_2: u32,
    _rsv1_3: u32,
    _rsv1_4: u32,
    _rsv1_5: u32,
    _rsv1_6: u32,
    _rsv1_7: u32,
    _rsv1_8: u32,
    _rsv1_9: u32,
    _rsv1_10: u32,
    vendor_0: u32,
    vendor_1: u32,
    vendor_2: u32,
    vendor_3: u32,
};

const HBAMemory = extern struct {
    cap: u32,
    ghc: u32,
    is: u32,
    pi: u32,
    vs: u32,
    ccc_ctl: u32,
    ccc_pts: u32,
    em_loc: u32,
    em_ctl: u32,
    cap2: u32,
    bohc: u32,
    _rsv_0: u32,
    _rsv_1: u32,
    _rsv_2: u32,
    _rsv_3: u32,
    _rsv_4: u32,
    _rsv_5: u32,
    _rsv_6: u32,
    _rsv_7: u32,
    _rsv_8: u32,
    _rsv_9: u32,
    _rsv_10: u32,
    _rsv_11: u32,
    _rsv_12: u32,
    vendor_0: u32,
    vendor_1: u32,
    vendor_2: u32,
    vendor_3: u32,
    vendor_4: u32,
    vendor_5: u32,
    vendor_6: u32,
    vendor_7: u32,
    vendor_8: u32,
    vendor_9: u32,
    vendor_10: u32,
    vendor_11: u32,
    vendor_12: u32,
    vendor_13: u32,
    vendor_14: u32,
    vendor_15: u32,
    vendor_16: u32,
    vendor_17: u32,
    vendor_18: u32,
    vendor_19: u32,
    vendor_20: u32,
    vendor_21: u32,
    vendor_22: u32,
    vendor_23: u32,

    fn get_port(self: *volatile HBAMemory, index: u8) *volatile HBAPort {
        const base = @intFromPtr(self);
        const port_offset = 0x100 + (@as(usize, index) * @sizeOf(HBAPort));
        return @ptrFromInt(base + port_offset);
    }
};

const HBACmdHeader = extern struct {
    cfl: u8,
    prdtl: u16,
    prdbc: u32,
    ctba: u64,
    _rsv_0: u32,
    _rsv_1: u32,
    _rsv_2: u32,
    _rsv_3: u32,
};

const HBAPRDTEntry = extern struct {
    dba: u64,
    _rsv0: u32,
    dbc: u32,
};

const HBACmdTable = extern struct {
    cfis: [64]u8,
    acmd: [16]u8,
    _rsv: [48]u8,
    prdt_entry: [1]HBAPRDTEntry,
};

const FISRegH2D = extern struct {
    fis_type: u8,
    pmport_c: u8,
    command: u8,
    featurel: u8,
    lba0: u8,
    lba1: u8,
    lba2: u8,
    device: u8,
    lba3: u8,
    lba4: u8,
    lba5: u8,
    featureh: u8,
    countl: u8,
    counth: u8,
    icc: u8,
    control: u8,
    _rsv: [4]u8,
};

var hba_mem: ?*volatile HBAMemory = null;
var port_num: u8 = 0;
var dma_buffer_phys: u64 = 0;

pub fn init(ahci_device: *pci.PCIDevice) !void {
    serial.print("Initializing AHCI controller at ");
    serial.print_hex(@as(u32, ahci_device.bus));
    serial.print(":");
    serial.print_hex(@as(u32, ahci_device.device));
    serial.print(".");
    serial.print_hex(@as(u32, ahci_device.function));
    serial.print("\n");

    pci.enable_bus_mastering(ahci_device);
    pci.enable_memory_space(ahci_device);

    const abar = ahci_device.bar5 & 0xFFFFFFF0;
    serial.print("  ABAR: ");
    serial.print_hex(abar);
    serial.print("\n");

    const PAGE_PRESENT: u64 = 0x1;
    const PAGE_WRITE: u64 = 0x2;

    var page_addr = abar;
    while (page_addr < abar + 0x2000) : (page_addr += 0x1000) {
        try paging.map_page(page_addr, page_addr, PAGE_PRESENT | PAGE_WRITE);
    }

    if (dma_buffer_phys == 0) {
        dma_buffer_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        try paging.map_page(dma_buffer_phys, dma_buffer_phys, PAGE_PRESENT | PAGE_WRITE);
    }

    hba_mem = @ptrFromInt(abar);
    const hba = hba_mem.?;

    serial.print("  AHCI Version: ");
    serial.print_hex(hba.vs);
    serial.print("\n");

    hba.ghc = hba.ghc | HBA_GHC_AE;

    serial.print("  Ports Implemented: ");
    serial.print_hex(hba.pi);
    serial.print("\n");

    var found_drive = false;
    var i: u8 = 0;
    while (i < 32) : (i += 1) {
        if ((hba.pi & (@as(u32, 1) << @as(u5, @truncate(i)))) != 0) {
            const port = hba.get_port(i);
            const dt = check_port_type(port);
            if (dt == 1) {
                serial.print("  Found SATA drive on port ");
                serial.print_hex(@as(u32, i));
                serial.print("\n");
                port_num = i;

                try port_rebase(port, i);
                found_drive = true;
                break;
            }
        }
    }

    if (!found_drive) {
        return error.NoDriveFound;
    }
}

fn check_port_type(port: *volatile HBAPort) u32 {
    const ssts = port.ssts;
    const ipm = (ssts >> 8) & 0x0F;
    const det = ssts & 0x0F;

    if (det != 3 or ipm != 1) return 0;

    const sig = port.sig;
    if (sig == 0x00000101) return 1;
    if (sig == 0xEB140101) return 2;
    if (sig == 0xC33C0101) return 3;
    if (sig == 0x96690101) return 4;

    return 0;
}

fn stop_cmd(port: *volatile HBAPort) void {
    port.cmd = port.cmd & ~HBA_PORT_CMD_ST;
    port.cmd = port.cmd & ~HBA_PORT_CMD_FRE;

    var spin: u32 = 0;
    while (spin < 500000) : (spin += 1) {
        if ((port.cmd & HBA_PORT_CMD_FR) != 0) continue;
        if ((port.cmd & HBA_PORT_CMD_CR) != 0) continue;
        break;
    }
}

fn start_cmd(port: *volatile HBAPort) void {
    var spin: u32 = 0;
    while ((port.cmd & HBA_PORT_CMD_CR) != 0 and spin < 500000) : (spin += 1) {}

    port.cmd = port.cmd | HBA_PORT_CMD_FRE;
    port.cmd = port.cmd | HBA_PORT_CMD_ST;
}

fn port_rebase(port: *volatile HBAPort, portno: u8) !void {
    stop_cmd(port);

    const clb_phys = pmm.alloc_page() orelse return error.OutOfMemory;
    const fb_phys = pmm.alloc_page() orelse return error.OutOfMemory;

    const PAGE_PRESENT: u64 = 0x1;
    const PAGE_WRITE: u64 = 0x2;
    try paging.map_page(clb_phys, clb_phys, PAGE_PRESENT | PAGE_WRITE);
    try paging.map_page(fb_phys, fb_phys, PAGE_PRESENT | PAGE_WRITE);

    port.clb = clb_phys;
    port.fb = fb_phys;

    @memset(@as([*]u8, @ptrFromInt(clb_phys))[0..4096], 0);
    @memset(@as([*]u8, @ptrFromInt(fb_phys))[0..4096], 0);

    const cmdheader = @as([*]volatile HBACmdHeader, @ptrFromInt(clb_phys));

    var i: usize = 0;
    while (i < 32) : (i += 1) {
        cmdheader[i].prdtl = 8;

        const cmdtable_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        try paging.map_page(cmdtable_phys, cmdtable_phys, PAGE_PRESENT | PAGE_WRITE);

        cmdheader[i].ctba = cmdtable_phys;

        @memset(@as([*]u8, @ptrFromInt(cmdtable_phys))[0..4096], 0);
    }

    port.serr = 0xFFFFFFFF;
    port.is = 0xFFFFFFFF;

    start_cmd(port);

    _ = portno;
}

fn find_cmdslot(port: *volatile HBAPort) ?u8 {
    const slots = port.sact | port.ci;

    var i: u8 = 0;
    while (i < 32) : (i += 1) {
        if ((slots & (@as(u32, 1) << @as(u5, @truncate(i)))) == 0) {
            return i;
        }
    }

    return null;
}

fn ahci_read_sector(lba: u64, buffer: *[SECTOR_SIZE]u8) bool {
    if (hba_mem == null) return false;

    const hba = hba_mem.?;
    const port = hba.get_port(port_num);

    port.is = 0xFFFFFFFF;

    const slot = find_cmdslot(port) orelse return false;

    const cmdheader = @as([*]volatile HBACmdHeader, @ptrFromInt(port.clb));
    cmdheader[slot].cfl = @sizeOf(FISRegH2D) / 4;
    cmdheader[slot].prdtl = 1;
    cmdheader[slot].prdbc = 0;

    const cmdtbl = @as(*volatile HBACmdTable, @ptrFromInt(cmdheader[slot].ctba));
    @memset(@as([*]u8, @ptrFromInt(cmdheader[slot].ctba))[0..256], 0);

    cmdtbl.prdt_entry[0].dba = dma_buffer_phys;
    cmdtbl.prdt_entry[0].dbc = (SECTOR_SIZE - 1) | (1 << 31);
    cmdtbl.prdt_entry[0]._rsv0 = 0;

    const cmdfis = @as(*volatile FISRegH2D, @ptrCast(&cmdtbl.cfis));
    cmdfis.fis_type = FIS_TYPE_REG_H2D;
    cmdfis.pmport_c = 0x80;
    cmdfis.command = ATA_CMD_READ_DMA_EX;

    cmdfis.lba0 = @truncate(lba & 0xFF);
    cmdfis.lba1 = @truncate((lba >> 8) & 0xFF);
    cmdfis.lba2 = @truncate((lba >> 16) & 0xFF);
    cmdfis.device = 1 << 6;
    cmdfis.lba3 = @truncate((lba >> 24) & 0xFF);
    cmdfis.lba4 = @truncate((lba >> 32) & 0xFF);
    cmdfis.lba5 = @truncate((lba >> 40) & 0xFF);

    cmdfis.countl = 1;
    cmdfis.counth = 0;

    var spin: u32 = 0;
    while ((port.tfd & (ATA_DEV_BUSY | ATA_DEV_DRQ)) != 0 and spin < 1000000) : (spin += 1) {}

    if (spin == 1000000) return false;

    const ci_bit = @as(u32, 1) << @as(u5, @truncate(slot));
    port.ci = ci_bit;

    spin = 0;
    while (spin < 10000000) : (spin += 1) {
        if ((port.ci & ci_bit) == 0) break;
        if ((port.is & HBA_PxIS_TFES) != 0) return false;
    }

    if ((port.ci & ci_bit) != 0) return false;

    const dma_buffer = @as([*]u8, @ptrFromInt(dma_buffer_phys));
    for (buffer, 0..) |*byte, i| {
        byte.* = dma_buffer[i];
    }

    return true;
}

pub const BlockDevice = struct {
    pub fn init() BlockDevice {
        return BlockDevice{};
    }

    pub fn read_sector(self: *BlockDevice, lba: u64, buffer: *[SECTOR_SIZE]u8) bool {
        _ = self;
        return ahci_read_sector(lba, buffer);
    }
};
