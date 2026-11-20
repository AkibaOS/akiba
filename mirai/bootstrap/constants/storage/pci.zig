//! Bootstrap PCI Configuration Mechanism Ports

pub const ADDRESS_PORT: u16 = 0xcf8;
pub const DATA_PORT: u16 = 0xcfc;
pub const ENABLE: u32 = 1 << 31;
pub const ADDRESS_SHIFT = @bitSizeOf(u8);
