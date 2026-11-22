//! Utility Check Text Fixtures

pub const EMPTY = "";

pub const ASCII_CASE_LOWER = "akiba-19";
pub const ASCII_CASE_UPPER = "AKIBA-19";
pub const ASCII_CASE_MIXED = "aKiBa-19";
pub const ASCII_CASE_LONGER = "akiba-190";
pub const ASCII_CASE_DIFFERENT = "akiba-18";
pub const ASCII_PUNCTUATION_LEFT = "a[b";
pub const ASCII_PUNCTUATION_RIGHT = "A{B";
pub const ASCII_COPY_SOURCE = "ABCDE";
pub const ASCII_SHORT_SOURCE = "AB";

pub const CRC_CHECK_INPUT = "123456789";
pub const CRC_PANGRAM_INPUT = "The quick brown fox jumps over the lazy dog";
pub const CRC_FRAMED_INPUT = "x123456789y";

pub const PATH_EMPTY_LOCATIONS = [_][]const u8{ EMPTY, "/", "\\", "/\\\\///\\" };
pub const PATH_MIXED = "///alpha\\\\beta//gamma\\";
pub const PATH_MIXED_COMPONENTS = [_][]const u8{ "alpha", "beta", "gamma" };
pub const PATH_LEXICAL = "C:\\folder\\.\\..\\file name.txt";
pub const PATH_LEXICAL_COMPONENTS = [_][]const u8{ "C:", "folder", ".", "..", "file name.txt" };
pub const PATH_DEVICE = "disk0:/System//Tools/";
pub const PATH_DEVICE_COMPONENTS = [_][]const u8{ "disk0:", "System", "Tools" };
pub const PATH_RELATIVE = "relative/file";
pub const PATH_RELATIVE_COMPONENTS = [_][]const u8{ "relative", "file" };
