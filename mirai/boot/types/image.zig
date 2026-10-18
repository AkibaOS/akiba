//! Kernel Image Manifest Types

pub const Region = struct {
    VirtualStart: u64 = 0,
    VirtualEnd: u64 = 0,
    PhysicalStart: u64 = 0,
    Writable: bool = false,
    Executable: bool = false,
};

pub const Manifest = struct {
    VirtualStart: u64 = 0,
    VirtualEnd: u64 = 0,
    PhysicalStart: u64 = 0,
    PhysicalEnd: u64 = 0,
    Text: Region = .{},
    Rodata: Region = .{},
    Data: Region = .{},
    DoubleFault: Region = .{},
    NonMaskable: Region = .{},
    MachineCheck: Region = .{},
    Debug: Region = .{},
};
