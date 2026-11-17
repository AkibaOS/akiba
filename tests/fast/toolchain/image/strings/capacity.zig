//! AFS Capacity Regression Identities And Paths

pub const CURRENT_DIRECTORY = ".";
pub const EMPTY_IDENTITY = "";
pub const BYTE_IDENTITY = "\xc3\xa9";
pub const FIRST_IDENTITY = "A";
pub const PREFIX_IDENTITY = "AB";
pub const SECOND_IDENTITY = "B";
pub const LOWER_IDENTITY = "a";
pub const INVALID_SLASH = "bad/name";
pub const INVALID_BACKSLASH = "bad\\name";
pub const INVALID_NUL = "bad\x00name";
pub const ALPHA_PATH = "Alpha";
pub const BETA_PATH = "beta";
pub const NESTED_PATH = "nested";
pub const CHILD_PATH = "nested/child";
pub const CHILD_IDENTITY = "child";
pub const HIDDEN_PATH = ".hidden";
pub const MISSING_PATH = "missing";
pub const PAYLOAD = "payload";
pub const FIRST_UTF16 = [_]u16{'A'};
pub const PREFIX_UTF16 = [_]u16{ 'A', 'B' };
pub const SECOND_UTF16 = [_]u16{'B'};
pub const LOWER_UTF16 = [_]u16{'a'};
