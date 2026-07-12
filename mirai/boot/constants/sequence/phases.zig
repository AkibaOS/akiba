//! Boot Phase Constants

pub const Phase = enum(u8) {
    cpu = 0,
    memory = 1,
    interrupts = 2,
    multicore = 3,
    world = 4,
    drivers = 5,
    filesystem = 6,
    pulse = 7,
    complete = 8,
};

pub const phase_names = [_][]const u8{
    "CPU",
    "Memory",
    "Interrupts",
    "Multicore",
    "World",
    "Drivers",
    "Filesystem",
    "Pulse",
    "Complete",
};

pub fn get_phase_name(phase: Phase) []const u8 {
    const index = @intFromEnum(phase);
    if (index < phase_names.len) {
        return phase_names[index];
    }
    return "Unknown";
}
