//! AHCI type definitions

pub const HBAPort = extern struct {
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
    _rsv1: [11]u32,
    vendor: [4]u32,
};

pub const HBAMemory = extern struct {
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
    _rsv: [13]u32,
    vendor: [24]u32,
};

pub const CmdHeader = extern struct {
    cfl: u8,
    prdtl: u16,
    prdbc: u32,
    ctba: u64,
    _rsv: [4]u32,
};

pub const PRDTEntry = extern struct {
    dba: u64,
    _rsv0: u32,
    dbc: u32,
};

pub const CmdTable = extern struct {
    cfis: [64]u8,
    acmd: [16]u8,
    _rsv: [48]u8,
    prdt_entry: [1]PRDTEntry,
};

pub const FISRegH2D = extern struct {
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
