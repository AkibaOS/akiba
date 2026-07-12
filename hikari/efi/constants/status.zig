//! Hikari EFI Status Code Constants

pub const SUCCESS: usize = 0;

pub const HIGH_BIT: usize = 1 << (@bitSizeOf(usize) - 1);

pub const LOAD_ERROR: usize = HIGH_BIT | 1;
pub const INVALID_PARAMETER: usize = HIGH_BIT | 2;
pub const UNSUPPORTED: usize = HIGH_BIT | 3;
pub const BAD_BUFFER_SIZE: usize = HIGH_BIT | 4;
pub const BUFFER_TOO_SMALL: usize = HIGH_BIT | 5;
pub const NOT_READY: usize = HIGH_BIT | 6;
pub const DEVICE_ERROR: usize = HIGH_BIT | 7;
pub const WRITE_PROTECTED: usize = HIGH_BIT | 8;
pub const OUT_OF_RESOURCES: usize = HIGH_BIT | 9;
pub const VOLUME_CORRUPTED: usize = HIGH_BIT | 10;
pub const VOLUME_FULL: usize = HIGH_BIT | 11;
pub const NO_MEDIA: usize = HIGH_BIT | 12;
pub const MEDIA_CHANGED: usize = HIGH_BIT | 13;
pub const NOT_FOUND: usize = HIGH_BIT | 14;
pub const ACCESS_DENIED: usize = HIGH_BIT | 15;
pub const NO_RESPONSE: usize = HIGH_BIT | 16;
pub const NO_MAPPING: usize = HIGH_BIT | 17;
pub const TIMEOUT: usize = HIGH_BIT | 18;
pub const NOT_STARTED: usize = HIGH_BIT | 19;
pub const ALREADY_STARTED: usize = HIGH_BIT | 20;
pub const ABORTED: usize = HIGH_BIT | 21;
pub const ICMP_ERROR: usize = HIGH_BIT | 22;
pub const TFTP_ERROR: usize = HIGH_BIT | 23;
pub const PROTOCOL_ERROR: usize = HIGH_BIT | 24;
pub const INCOMPATIBLE_VERSION: usize = HIGH_BIT | 25;
pub const SECURITY_VIOLATION: usize = HIGH_BIT | 26;
pub const CRC_ERROR: usize = HIGH_BIT | 27;
pub const END_OF_MEDIA: usize = HIGH_BIT | 28;
pub const END_OF_UNIT: usize = HIGH_BIT | 31;
pub const INVALID_LANGUAGE: usize = HIGH_BIT | 32;
pub const COMPROMISED_DATA: usize = HIGH_BIT | 33;
pub const IP_ADDRESS_CONFLICT: usize = HIGH_BIT | 34;
pub const HTTP_ERROR: usize = HIGH_BIT | 35;
