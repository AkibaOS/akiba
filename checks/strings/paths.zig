//! Manual Guest Discovery Paths

pub const CURRENT_DIRECTORY = ".";
pub const RUNS_DIRECTORY = "zig-out/checks/runs";
pub const RUN_NAME = "run-{x}";
pub const SERIAL_FILE = "serial.log";
pub const VARIABLES_FILE = "uefi-vars.fd";
pub const QEMU_NAME = "qemu-system-x86_64";
pub const QEMU_ENV = "QEMU";
pub const PATH_ENV = "PATH";
pub const UEFI_CODE_ENV = "AKIBA_UEFI_CODE";
pub const UEFI_VARS_ENV = "AKIBA_UEFI_VARS";
pub const EXECUTABLE_SUFFIX = ".exe";
pub const SHIM_SUFFIX = ".shim";
pub const SUFFIX_FORMAT = "{s}{s}";
pub const SHIM_PATH_KEY = "path";
pub const SHIM_ARGUMENTS_KEY = "args";
pub const EMPTY_QUOTED = "\"\"";
pub const WHITESPACE = " \t\r\n";
pub const LINE_SEPARATORS = "\r\n";
pub const PATH_MARKERS = "/";
pub const PATH_MARKERS_WINDOWS = "/\\:";
pub const UNSAFE_PATH_CHARACTERS = ",\"\r\n\x00";
pub const FIRMWARE_RELATIVE_DIRECTORIES = [_][]const u8{
    "share", "../share/qemu", "../share/OVMF", "../share/edk2/ovmf", "../share/edk2/x64",
};
pub const FIRMWARE_PAIRS = [_][2][]const u8{
    .{ "edk2-x86_64-code.fd", "edk2-i386-vars.fd" },
    .{ "OVMF_CODE.fd", "OVMF_VARS.fd" },
    .{ "OVMF_CODE_4M.fd", "OVMF_VARS_4M.fd" },
};
pub const MISSING_QEMU = "QEMU executable not found; set QEMU or add qemu-system-x86_64 to PATH.";
pub const MISSING_IMAGE = "Cached guest check image missing; invoke make test-guest.";
pub const UNPAIRED_FIRMWARE = "Set both AKIBA_UEFI_CODE and AKIBA_UEFI_VARS, or neither.";
pub const INVALID_FIRMWARE = "UEFI override is not a readable regular file: {s}.";
pub const MISSING_FIRMWARE = "Matching UEFI code/variables files not found; set AKIBA_UEFI_CODE and AKIBA_UEFI_VARS.";
pub const UNSAFE_PATH = "QEMU paths must not contain commas, double quotes, line breaks, or NUL bytes.";
