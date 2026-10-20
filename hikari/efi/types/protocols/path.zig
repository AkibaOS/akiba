//! Hikari EFI Device Location Protocol

pub const DeviceLocationProtocol = extern struct {
    DeviceType: u8,
    SubType: u8,
    Length: [2]u8,
};

pub const HardDriveDeviceLocation = extern struct {
    Header: DeviceLocationProtocol,
    PartitionNumber: u32,
    PartitionStart: u64,
    PartitionSize: u64,
    PartitionSignature: [16]u8,
    PartitionFormat: u8,
    SignatureType: u8,
};

pub const UnitLocationDeviceLocation = extern struct {
    Header: DeviceLocationProtocol,
    LocationName: [*:0]u16,
};
