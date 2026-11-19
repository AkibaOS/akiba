//! Standard Diagnostic Group Order

const access = @import("tests").strings.access;
const acquisition = @import("tests").strings.acquisition;
const boot = @import("tests").strings.boot;
const completion = @import("tests").strings.completion;
const context = @import("tests").strings.context;
const crimson = @import("tests").strings.crimson;
const elf = @import("tests").strings.elf;
const guest = @import("tests").strings.guest;
const hikari = @import("tests").strings.hikari;
const invocations = @import("tests").strings.invocations;
const memory = @import("tests").strings.memory;
const postman = @import("tests").strings.postman;
const retention = @import("tests").strings.retention;
const sensei = @import("tests").strings.sensei;

pub const GROUPS = [_][]const u8{
    acquisition.GROUP,
    hikari.GROUP_ELF,
    hikari.GROUP_EFI,
    boot.GROUP,
    memory.GROUP_PMM,
    memory.GROUP_KERNEL,
    memory.GROUP_KAGAMI,
    memory.GROUP_OWNED,
    guest.GROUP_MEMORY,
    elf.GROUP,
    sensei.GROUP,
    retention.GROUP,
    retention.GROUP_POPULATION,
    guest.GROUP_LIFECYCLE,
    guest.GROUP_COMPLETION,
    access.GROUP,
    guest.GROUP_PERSONA,
    invocations.GROUP,
    completion.GROUP,
    guest.GROUP_TERMINATION,
    postman.GROUP,
    context.GROUP,
    crimson.GROUP,
};
