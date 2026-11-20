//! Invalid AHCI Command Geometry

pub const CommandError = error{ InvalidDmaPage, InvalidSector, UnsupportedDisk, UnsupportedSectorSize };
