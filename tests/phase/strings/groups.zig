//! Shared Diagnostic Group Labels

pub const ACCESS_GROUP = "CHECK GROUP Hardware access faults\n";
pub const ACQUISITION_GROUP = "CHECK GROUP Hikari disk acquisition\n";
pub const BOOT_GROUP = "CHECK GROUP Boot and CPU\n";
pub const COMPLETION_GROUP = "CHECK GROUP Persona Kata outcomes\n";
pub const CONTEXT_GROUP = "CHECK GROUP Native Thread context\n";
pub const CRIMSON_GROUP = "CHECK GROUP Crimson local contracts\n";
pub const ELF_GROUP = "CHECK GROUP ELF image construction\n";
pub const GUEST_GROUP_MEMORY = "CHECK GROUP Memory protections\n";
pub const GUEST_GROUP_LIFECYCLE = "CHECK GROUP Kata lifecycle\n";
pub const GUEST_GROUP_COMPLETION = "CHECK GROUP Completion ownership\n";
pub const GUEST_GROUP_PERSONA = "CHECK GROUP Persona Mode\n";
pub const GUEST_GROUP_TERMINATION = "CHECK GROUP Persona completion\n";
pub const HIKARI_GROUP_ELF = "CHECK GROUP Hikari ELF validation\n";
pub const HIKARI_GROUP_EFI = "CHECK GROUP EFI buffer client\n";
pub const INVOCATIONS_GROUP = "CHECK GROUP Returning invocations\n";
pub const MEMORY_GROUP_PMM = "CHECK GROUP Physical memory\n";
pub const MEMORY_GROUP_KERNEL = "CHECK GROUP Kernel allocation\n";
pub const MEMORY_GROUP_KAGAMI = "CHECK GROUP Kagami mappings\n";
pub const MEMORY_GROUP_OWNED = "CHECK GROUP Owned copies\n";
pub const POSTMAN_GROUP = "CHECK GROUP Postman Persona transport\n";
pub const RETENTION_GROUP = "CHECK GROUP Outcome retention\n";
pub const RETENTION_GROUP_POPULATION = "CHECK GROUP Execution populations\n";
pub const SENSEI_GROUP = "CHECK GROUP Sensei scheduling\n";
