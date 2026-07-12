//! Hikari EFI Protocol GUIDs

const types = @import("../types/types.zig");

const GUID = types.base.GUID;

pub const LOADED_IMAGE_PROTOCOL align(8) = GUID{
    .TimeLow = 0x5B1B31A1,
    .TimeMid = 0x9562,
    .TimeHighAndVersion = 0x11d2,
    .ClockSequenceAndNode = .{ 0x8E, 0x3F, 0x00, 0xA0, 0xC9, 0x69, 0x72, 0x3B },
};

pub const SIMPLE_UNIT_SYSTEM_PROTOCOL align(8) = GUID{
    .TimeLow = 0x0964e5b22,
    .TimeMid = 0x6459,
    .TimeHighAndVersion = 0x11d2,
    .ClockSequenceAndNode = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const UNIT_INFO align(8) = GUID{
    .TimeLow = 0x09576e92,
    .TimeMid = 0x6d3f,
    .TimeHighAndVersion = 0x11d2,
    .ClockSequenceAndNode = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const UNIT_SYSTEM_INFO align(8) = GUID{
    .TimeLow = 0x09576e93,
    .TimeMid = 0x6d3f,
    .TimeHighAndVersion = 0x11d2,
    .ClockSequenceAndNode = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const GRAPHICS_OUTPUT_PROTOCOL align(8) = GUID{
    .TimeLow = 0x9042a9de,
    .TimeMid = 0x23dc,
    .TimeHighAndVersion = 0x4a38,
    .ClockSequenceAndNode = .{ 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a },
};

pub const BLOCK_IO_PROTOCOL align(8) = GUID{
    .TimeLow = 0x964e5b21,
    .TimeMid = 0x6459,
    .TimeHighAndVersion = 0x11d2,
    .ClockSequenceAndNode = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const BLOCK_IO2_PROTOCOL align(8) = GUID{
    .TimeLow = 0xa77b2472,
    .TimeMid = 0xe282,
    .TimeHighAndVersion = 0x4e9f,
    .ClockSequenceAndNode = .{ 0xa2, 0x45, 0xc2, 0xc0, 0xe2, 0x7b, 0xbc, 0xc1 },
};

pub const DISK_IO_PROTOCOL align(8) = GUID{
    .TimeLow = 0xce345171,
    .TimeMid = 0xba0b,
    .TimeHighAndVersion = 0x11d2,
    .ClockSequenceAndNode = .{ 0x8e, 0x4f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const DISK_IO2_PROTOCOL align(8) = GUID{
    .TimeLow = 0x151c8eae,
    .TimeMid = 0x7f2c,
    .TimeHighAndVersion = 0x472c,
    .ClockSequenceAndNode = .{ 0x9e, 0x54, 0x98, 0x28, 0x19, 0x4f, 0x6a, 0x88 },
};

pub const DEVICE_LOCATION_PROTOCOL align(8) = GUID{
    .TimeLow = 0x09576e91,
    .TimeMid = 0x6d3f,
    .TimeHighAndVersion = 0x11d2,
    .ClockSequenceAndNode = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const SIMPLE_TEXT_INPUT_PROTOCOL align(8) = GUID{
    .TimeLow = 0x387477c1,
    .TimeMid = 0x69c7,
    .TimeHighAndVersion = 0x11d2,
    .ClockSequenceAndNode = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const SIMPLE_TEXT_OUTPUT_PROTOCOL align(8) = GUID{
    .TimeLow = 0x387477c2,
    .TimeMid = 0x69c7,
    .TimeHighAndVersion = 0x11d2,
    .ClockSequenceAndNode = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const ACPI_20_TABLE align(8) = GUID{
    .TimeLow = 0x8868e871,
    .TimeMid = 0xe4f1,
    .TimeHighAndVersion = 0x11d3,
    .ClockSequenceAndNode = .{ 0xbc, 0x22, 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81 },
};

pub const ACPI_10_TABLE align(8) = GUID{
    .TimeLow = 0xeb9d2d30,
    .TimeMid = 0x2d88,
    .TimeHighAndVersion = 0x11d3,
    .ClockSequenceAndNode = .{ 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
};

pub const SMBIOS_TABLE align(8) = GUID{
    .TimeLow = 0xeb9d2d31,
    .TimeMid = 0x2d88,
    .TimeHighAndVersion = 0x11d3,
    .ClockSequenceAndNode = .{ 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
};

pub const SMBIOS3_TABLE align(8) = GUID{
    .TimeLow = 0xf2fd1544,
    .TimeMid = 0x9794,
    .TimeHighAndVersion = 0x4a2c,
    .ClockSequenceAndNode = .{ 0x99, 0x2e, 0xe5, 0xbb, 0xcf, 0x20, 0xe3, 0x94 },
};

pub const GPT_PARTITION_TYPE_EFI_SYSTEM align(8) = GUID{
    .TimeLow = 0xC12A7328,
    .TimeMid = 0xF81F,
    .TimeHighAndVersion = 0x11D2,
    .ClockSequenceAndNode = .{ 0xBA, 0x4B, 0x00, 0xA0, 0xC9, 0x3E, 0xC9, 0x3B },
};

pub const GPT_PARTITION_TYPE_AKIBA_AFS align(8) = GUID{
    .TimeLow = 0x414B4942,
    .TimeMid = 0x4146,
    .TimeHighAndVersion = 0x5300,
    .ClockSequenceAndNode = .{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01 },
};
