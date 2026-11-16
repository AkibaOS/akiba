//! Explicit Guest Regression Execution

const bootlabels = @import("tests").strings.boot;
const guest = @import("tests").guest;
const hikarilabels = @import("tests").strings.hikari;
const labels = @import("tests").strings.guest;
const memorylabels = @import("tests").strings.memory;
const serial = @import("mirai").drivers.serial.write;
const verify = @import("tests").verify;

pub fn execute() void {
    serial.printf(labels.BEGIN, .{});
    switch (guest.support.selector.selected()) {
        .Standard => {},
        .PulseDeath => {
            guest.mirai.kata.fatal.run() catch |failure| verify.failure(failure);
            return;
        },
    }
    serial.printf(hikarilabels.GROUP_ELF, .{});
    guest.hikari.loader.validation.run() catch |failure| verify.failure(failure);
    serial.printf(hikarilabels.GROUP_EFI, .{});
    guest.hikari.efi.buffer.run();
    serial.printf(bootlabels.GROUP, .{});
    guest.mirai.boot.invariants.run();
    serial.printf(memorylabels.GROUP_PMM, .{});
    guest.mirai.pmm.frames.run() catch |failure| verify.failure(failure);
    guest.mirai.pmm.ranges.run() catch |failure| verify.failure(failure);
    guest.mirai.pmm.reservation.run() catch |failure| verify.failure(failure);
    serial.printf(memorylabels.GROUP_KERNEL, .{});
    guest.mirai.memory.allocation.run() catch |failure| verify.failure(failure);
    guest.mirai.memory.zone.run() catch |failure| verify.failure(failure);
    guest.mirai.memory.stack.run() catch |failure| verify.failure(failure);
    serial.printf(memorylabels.GROUP_KAGAMI, .{});
    guest.mirai.kagami.mapping.run() catch |failure| verify.failure(failure);
    guest.mirai.kagami.ownership.run() catch |failure| verify.failure(failure);
    guest.mirai.kagami.rejection.run() catch |failure| verify.failure(failure);
    serial.printf(memorylabels.GROUP_OWNED, .{});
    guest.mirai.user.regressions.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_MEMORY, .{});
    guest.mirai.user.memory.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_LIFECYCLE, .{});
    guest.mirai.kata.lifecycle.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_COMPLETION, .{});
    guest.mirai.kata.completion.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_PERSONA, .{});
    guest.mirai.thread.persona.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_TERMINATION, .{});
    guest.mirai.invocations.termination.run() catch |failure| verify.failure(failure);
    serial.printf(labels.COMPLETE, .{verify.count()});
}
