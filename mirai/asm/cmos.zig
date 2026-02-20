//! CMOS/RTC Operations

const io = @import("io.zig");
const ports = @import("../common/constants/ports.zig");

/// Read a CMOS register
pub inline fn read_register(reg: u8) u8 {
    io.out_byte(ports.CMOS_ADDRESS, reg);
    return io.in_byte(ports.CMOS_DATA);
}

/// Write to a CMOS register
pub inline fn write_register(reg: u8, value: u8) void {
    io.out_byte(ports.CMOS_ADDRESS, reg);
    io.out_byte(ports.CMOS_DATA, value);
}

/// Read RTC seconds (BCD)
pub inline fn read_seconds() u8 {
    return read_register(0x00);
}

/// Read RTC minutes (BCD)
pub inline fn read_minutes() u8 {
    return read_register(0x02);
}

/// Read RTC hours (BCD)
pub inline fn read_hours() u8 {
    return read_register(0x04);
}

/// Read RTC day of month (BCD)
pub inline fn read_day() u8 {
    return read_register(0x07);
}

/// Read RTC month (BCD)
pub inline fn read_month() u8 {
    return read_register(0x08);
}

/// Read RTC year (BCD, 00-99)
pub inline fn read_year() u8 {
    return read_register(0x09);
}

/// Read RTC century (BCD)
pub inline fn read_century() u8 {
    return read_register(0x32);
}

/// Convert BCD to binary
pub inline fn bcd_to_bin(bcd: u8) u8 {
    return (bcd & 0x0F) + ((bcd >> 4) * 10);
}
