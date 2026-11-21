//! AHCI Driver Disk Refusals

pub const DiskError = error{ DeviceRefused, InvalidSectorBuffer, VolumeMismatch };
