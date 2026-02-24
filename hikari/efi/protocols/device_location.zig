//! Hikari EFI Device Location Protocol

pub const DeviceLocationProtocol = extern struct {
    device_type: u8,
    sub_type: u8,
    length: [2]u8,
};

pub const device_location_type_hardware: u8 = 0x01;
pub const device_location_type_acpi: u8 = 0x02;
pub const device_location_type_messaging: u8 = 0x03;
pub const device_location_type_media: u8 = 0x04;
pub const device_location_type_bios_boot: u8 = 0x05;
pub const device_location_type_end: u8 = 0x7F;

pub const device_location_sub_type_end_entire: u8 = 0xFF;
pub const device_location_sub_type_end_instance: u8 = 0x01;

pub const device_location_sub_type_hard_drive: u8 = 0x01;
pub const device_location_sub_type_cdrom: u8 = 0x02;
pub const device_location_sub_type_vendor: u8 = 0x03;
pub const device_location_sub_type_unit_location: u8 = 0x04;
pub const device_location_sub_type_media_protocol: u8 = 0x05;
pub const device_location_sub_type_piwg_firmware_unit: u8 = 0x06;
pub const device_location_sub_type_piwg_firmware_volume: u8 = 0x07;
pub const device_location_sub_type_relative_offset_range: u8 = 0x08;
pub const device_location_sub_type_ram_disk: u8 = 0x09;

pub const HardDriveDeviceLocation = extern struct {
    header: DeviceLocationProtocol,
    partition_number: u32,
    partition_start: u64,
    partition_size: u64,
    partition_signature: [16]u8,
    partition_format: u8,
    signature_type: u8,
};

pub const partition_format_mbr: u8 = 0x01;
pub const partition_format_gpt: u8 = 0x02;

pub const signature_type_none: u8 = 0x00;
pub const signature_type_mbr: u8 = 0x01;
pub const signature_type_guid: u8 = 0x02;

pub const UnitLocationDeviceLocation = extern struct {
    header: DeviceLocationProtocol,
    location_name: [*:0]u16,
};
