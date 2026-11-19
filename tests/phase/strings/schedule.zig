//! Standard Diagnostic Group Order

const grouptext = @import("tests").phase.strings.groups;

pub const GROUPS = [_][]const u8{
    grouptext.ACQUISITION_GROUP,
    grouptext.HIKARI_GROUP_ELF,
    grouptext.HIKARI_GROUP_EFI,
    grouptext.BOOT_GROUP,
    grouptext.MEMORY_GROUP_PMM,
    grouptext.MEMORY_GROUP_KERNEL,
    grouptext.MEMORY_GROUP_KAGAMI,
    grouptext.MEMORY_GROUP_OWNED,
    grouptext.GUEST_GROUP_MEMORY,
    grouptext.ELF_GROUP,
    grouptext.SENSEI_GROUP,
    grouptext.RETENTION_GROUP,
    grouptext.RETENTION_GROUP_POPULATION,
    grouptext.GUEST_GROUP_LIFECYCLE,
    grouptext.GUEST_GROUP_COMPLETION,
    grouptext.ACCESS_GROUP,
    grouptext.GUEST_GROUP_PERSONA,
    grouptext.INVOCATIONS_GROUP,
    grouptext.COMPLETION_GROUP,
    grouptext.GUEST_GROUP_TERMINATION,
    grouptext.POSTMAN_GROUP,
    grouptext.CONTEXT_GROUP,
    grouptext.CRIMSON_GROUP,
};
