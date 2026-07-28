//! Boot Phase Type

const strings = @import("mirai").boot.strings;

const phases = strings.sequence.phases;

pub const Phase = enum(u8) {
    CPU = 0,
    Memory = 1,
    Interrupts = 2,
    Multicore = 3,
    World = 4,
    Drivers = 5,
    Filesystem = 6,
    Pulse = 7,
    Complete = 8,

    pub fn name(self: Phase) []const u8 {
        return switch (self) {
            .CPU => phases.PHASE_CPU,
            .Memory => phases.PHASE_MEMORY,
            .Interrupts => phases.PHASE_INTERRUPTS,
            .Multicore => phases.PHASE_MULTICORE,
            .World => phases.PHASE_WORLD,
            .Drivers => phases.PHASE_DRIVERS,
            .Filesystem => phases.PHASE_FILESYSTEM,
            .Pulse => phases.PHASE_PULSE,
            .Complete => phases.PHASE_COMPLETE,
        };
    }
};
