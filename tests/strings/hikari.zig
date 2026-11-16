//! Hikari Guest Regression Labels

pub const GROUP_ELF = "CHECK GROUP Hikari ELF validation\n";
pub const GROUP_EFI = "CHECK GROUP EFI buffer client\n";

pub const ELF_VALID = "Hikari accepts an independently encoded strict seven-segment Mirai ELF";
pub const ELF_HEADER_MISSING = "Hikari rejects missing and truncated ELF headers";
pub const ELF_HEADER_MALFORMED = "Hikari rejects a corrupted ELF header";
pub const ELF_TABLE_MISSING = "Hikari rejects an absent ELF program table";
pub const ELF_TABLE_TRUNCATED = "Hikari rejects a truncated ELF program table";
pub const ELF_TABLE_MALFORMED = "Hikari rejects malformed ELF program table geometry";
pub const ELF_DYNAMIC = "Hikari rejects dynamic kernel segments";
pub const ELF_INTERPRETER = "Hikari rejects interpreter kernel segments";
pub const ELF_WRITE_EXECUTE = "Hikari rejects writable executable kernel segments";
pub const ELF_OVERLAP = "Hikari rejects overlapping kernel pages";
pub const ELF_ENTRY = "Hikari rejects an entry outside file-backed executable bytes";
pub const ELF_LAYOUT = "Hikari enforces the strict Mirai stack guard layout";
pub const ELF_FILE_BOUNDS = "Hikari rejects segment bytes extending beyond the ELF input";
pub const ELF_ADDRESS_BOUNDS = "Hikari rejects segment address overflow";
pub const BUFFER_ALIGNMENT = "EFI aligned buffers retain the allocation owner and bound data writes";
pub const BUFFER_RELEASE = "EFI buffer release frees the original owner and clears its size";
pub const BUFFER_DOUBLE_RELEASE = "EFI buffer release does not free an owner twice";
pub const BUFFER_REJECTIONS = "EFI invalid size alignment and size overflow avoid allocation callbacks";
pub const BUFFER_FAILURE = "EFI allocation failure creates no owned buffer";
pub const BUFFER_ADDRESS_OVERFLOW = "EFI address overflow releases the original allocation";
