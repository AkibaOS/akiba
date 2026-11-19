//! Native Diagnostic Linker Arguments

pub const LLD = "ld.lld";
pub const SHARED = "-shared";
pub const SYSV_HASH = "--hash-style=sysv";
pub const SONAME = "--soname";
pub const OUTPUT = "-o";
pub const PIE = "-pie";
pub const NATIVE = "--no-dynamic-linker";
pub const LINK_OPTION = "-z";
pub const EAGER = "now";
pub const ENTRY = "--entry";
