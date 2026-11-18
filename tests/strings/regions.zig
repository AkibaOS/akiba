//! Firmware Map Conversion Regression Labels

pub const GROWTH = "early canonical memory map accepts more than former descriptor backing and preserves every region";
pub const STRIDE = "early memory map accepts representable extended descriptor strides without truncating known fields";
pub const REJECT = "memory map rejects invalid stride version extent overflow alignment zero length and overlapping regions";
pub const PRESERVE = "late invalid descriptor rejection preserves the raw map before consumption begins";
pub const RELEASE = "memory map conversion needs no allocation and returns its caller-owned test buffer unchanged in ownership";
