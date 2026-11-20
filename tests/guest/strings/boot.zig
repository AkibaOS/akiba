//! Boot Contract Regression Labels

pub const ROOT = "owned kernel CR3 and high stack are active";
pub const FRAMES = "all bootstrap table records belong to the permanent active kernel root after transfer";
pub const LOW = "low identity mapping is absent after handoff";
pub const RETIRED_ROOT = "retired Hikari root is reusable only after Mirai activates its own root";
pub const BOOT_VOLUME = "Mirai retains the selected AFS GPT identity after Hikari memory retirement";
pub const PROTECTION = "CPU write protect and no-execute are enabled";
pub const FPU = "CPU floating point mode matches context switching contract";
pub const PAGE_MODE = "unsupported PCID and five-level paging remain disabled";
pub const TEXT = "kernel text and physmap alias have exact protections";
pub const RODATA = "kernel read-only data and alias are nonwritable NX";
pub const FRAMEBUFFER = "framebuffer alias is supervisor uncached NX";
pub const TSS_STACK = "active Thread stack matches TSS RSP0";
pub const IST = "exception stacks have isolated guards and NX bodies";
pub const INVOCATION = "Persona invocation gate is Ring3 interrupt entry";
pub const GUARD = "nested interrupt guards preserve prior IF state";
pub const TSS_DATA = "TSS index and reset operations preserve layout state";
