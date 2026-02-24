//! Hikari EFI Protocol GUIDs

const types = @import("../types/types.zig");
const Guid = types.Guid;

pub const loaded_image_protocol = Guid{
    .time_low = 0x5B1B31A1,
    .time_mid = 0x9562,
    .time_high_and_version = 0x11d2,
    .clock_sequence_and_node = .{ 0x8E, 0x3F, 0x00, 0xA0, 0xC9, 0x69, 0x72, 0x3B },
};

pub const simple_unit_system_protocol = Guid{
    .time_low = 0x0964e5b22,
    .time_mid = 0x6459,
    .time_high_and_version = 0x11d2,
    .clock_sequence_and_node = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const unit_info = Guid{
    .time_low = 0x09576e92,
    .time_mid = 0x6d3f,
    .time_high_and_version = 0x11d2,
    .clock_sequence_and_node = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const unit_system_info = Guid{
    .time_low = 0x09576e93,
    .time_mid = 0x6d3f,
    .time_high_and_version = 0x11d2,
    .clock_sequence_and_node = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const graphics_output_protocol = Guid{
    .time_low = 0x9042a9de,
    .time_mid = 0x23dc,
    .time_high_and_version = 0x4a38,
    .clock_sequence_and_node = .{ 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a },
};

pub const block_io_protocol = Guid{
    .time_low = 0x964e5b21,
    .time_mid = 0x6459,
    .time_high_and_version = 0x11d2,
    .clock_sequence_and_node = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const block_io2_protocol = Guid{
    .time_low = 0xa77b2472,
    .time_mid = 0xe282,
    .time_high_and_version = 0x4e9f,
    .clock_sequence_and_node = .{ 0xa2, 0x45, 0xc2, 0xc0, 0xe2, 0x7b, 0xbc, 0xc1 },
};

pub const disk_io_protocol = Guid{
    .time_low = 0xce345171,
    .time_mid = 0xba0b,
    .time_high_and_version = 0x11d2,
    .clock_sequence_and_node = .{ 0x8e, 0x4f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const disk_io2_protocol = Guid{
    .time_low = 0x151c8eae,
    .time_mid = 0x7f2c,
    .time_high_and_version = 0x472c,
    .clock_sequence_and_node = .{ 0x9e, 0x54, 0x98, 0x28, 0x19, 0x4f, 0x6a, 0x88 },
};

pub const device_location_protocol = Guid{
    .time_low = 0x09576e91,
    .time_mid = 0x6d3f,
    .time_high_and_version = 0x11d2,
    .clock_sequence_and_node = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const simple_text_input_protocol = Guid{
    .time_low = 0x387477c1,
    .time_mid = 0x69c7,
    .time_high_and_version = 0x11d2,
    .clock_sequence_and_node = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const simple_text_output_protocol = Guid{
    .time_low = 0x387477c2,
    .time_mid = 0x69c7,
    .time_high_and_version = 0x11d2,
    .clock_sequence_and_node = .{ 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
};

pub const acpi_20_table = Guid{
    .time_low = 0x8868e871,
    .time_mid = 0xe4f1,
    .time_high_and_version = 0x11d3,
    .clock_sequence_and_node = .{ 0xbc, 0x22, 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81 },
};

pub const acpi_10_table = Guid{
    .time_low = 0xeb9d2d30,
    .time_mid = 0x2d88,
    .time_high_and_version = 0x11d3,
    .clock_sequence_and_node = .{ 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
};

pub const smbios_table = Guid{
    .time_low = 0xeb9d2d31,
    .time_mid = 0x2d88,
    .time_high_and_version = 0x11d3,
    .clock_sequence_and_node = .{ 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
};

pub const smbios3_table = Guid{
    .time_low = 0xf2fd1544,
    .time_mid = 0x9794,
    .time_high_and_version = 0x4a2c,
    .clock_sequence_and_node = .{ 0x99, 0x2e, 0xe5, 0xbb, 0xcf, 0x20, 0xe3, 0x94 },
};

pub const gpt_partition_type_efi_system = Guid{
    .time_low = 0xC12A7328,
    .time_mid = 0xF81F,
    .time_high_and_version = 0x11D2,
    .clock_sequence_and_node = .{ 0xBA, 0x4B, 0x00, 0xA0, 0xC9, 0x3E, 0xC9, 0x3B },
};

pub const gpt_partition_type_akiba_afs = Guid{
    .time_low = 0x414B4942,
    .time_mid = 0x4146,
    .time_high_and_version = 0x5300,
    .clock_sequence_and_node = .{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01 },
};
