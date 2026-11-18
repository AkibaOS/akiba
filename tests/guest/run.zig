//! Explicit Guest Regression Execution

const accesslabels = @import("tests").strings.access;
const acquisitionlabels = @import("tests").strings.acquisition;
const bootlabels = @import("tests").strings.boot;
const completionlabels = @import("tests").strings.completion;
const contextlabels = @import("tests").strings.context;
const crimsonlabels = @import("tests").strings.crimson;
const driverlabels = @import("tests").strings.drivers;
const elflabels = @import("tests").strings.elf;
const guest = @import("tests").guest;
const hikarilabels = @import("tests").strings.hikari;
const invocationlabels = @import("tests").strings.invocations;
const labels = @import("tests").strings.guest;
const memorylabels = @import("tests").strings.memory;
const postmanlabels = @import("tests").strings.postman;
const retentionlabels = @import("tests").strings.retention;
const scenariolabels = @import("tests").strings.scenario;
const senseilabels = @import("tests").strings.sensei;
const serial = @import("mirai").drivers.serial.write;
const verify = @import("tests").verify;

pub fn execute() void {
    serial.printf(labels.BEGIN, .{});
    switch (guest.support.selector.selected()) {
        .Standard => {},
        .Collapse => @call(.never_inline, guest.mirai.crimson.fatal.run, .{}),
        .Firmware => @panic(scenariolabels.INVALID),
        .Devices => {
            serial.printf(driverlabels.GROUP, .{});
            @call(.never_inline, guest.mirai.drivers.input.run, .{});
            serial.printf(labels.COMPLETE, .{verify.count()});
            return;
        },
        .PulseDeath => {
            check(guest.mirai.kata.fatal.run);
            return;
        },
    }
    serial.printf(acquisitionlabels.GROUP, .{});
    check(guest.hikari.disk.gpt.run);
    @call(.never_inline, guest.hikari.disk.reader.run, .{});
    check(guest.hikari.disk.unit.run);
    serial.printf(hikarilabels.GROUP_ELF, .{});
    check(guest.hikari.loader.validation.run);
    serial.printf(hikarilabels.GROUP_EFI, .{});
    @call(.never_inline, guest.hikari.efi.buffer.run, .{});
    serial.printf(bootlabels.GROUP, .{});
    @call(.never_inline, guest.mirai.boot.invariants.run, .{});
    check(guest.mirai.boot.regions.run);
    serial.printf(memorylabels.GROUP_PMM, .{});
    check(guest.mirai.pmm.frames.run);
    check(guest.mirai.pmm.ranges.run);
    check(guest.mirai.pmm.reservation.run);
    serial.printf(memorylabels.GROUP_KERNEL, .{});
    check(guest.mirai.memory.allocation.run);
    check(guest.mirai.memory.range.run);
    check(guest.mirai.memory.heap.run);
    check(guest.mirai.memory.validation.run);
    check(guest.mirai.memory.allocator.run);
    check(guest.mirai.memory.zone.run);
    check(guest.mirai.memory.growth.run);
    check(guest.mirai.memory.validity.run);
    check(guest.mirai.memory.failure.run);
    check(guest.mirai.memory.pool.run);
    check(guest.mirai.memory.stack.run);
    check(guest.mirai.memory.reuse.run);
    check(guest.mirai.memory.reservation.run);
    serial.printf(memorylabels.GROUP_KAGAMI, .{});
    check(guest.mirai.kagami.mapping.run);
    check(guest.mirai.kagami.ownership.run);
    check(guest.mirai.kagami.rejection.run);
    check(guest.mirai.kagami.effective.run);
    check(guest.mirai.kagami.failure.run);
    check(guest.mirai.kagami.graph.run);
    check(guest.mirai.kagami.population.run);
    check(guest.mirai.kagami.alias.run);
    serial.printf(memorylabels.GROUP_OWNED, .{});
    check(guest.mirai.user.regressions.run);
    check(guest.mirai.user.population.run);
    check(guest.mirai.user.failure.run);
    serial.printf(labels.GROUP_MEMORY, .{});
    check(guest.mirai.user.memory.run);
    serial.printf(elflabels.GROUP, .{});
    check(guest.mirai.bootstrap.image.run);
    check(guest.mirai.bootstrap.rejection.run);
    check(guest.mirai.bootstrap.pressure.run);
    check(guest.mirai.bootstrap.growth.run);
    check(guest.mirai.bootstrap.finalization.run);
    check(guest.mirai.bootstrap.order.run);
    check(guest.mirai.bootstrap.execution.run);
    serial.printf(senseilabels.GROUP, .{});
    check(guest.mirai.sensei.admission.run);
    check(guest.mirai.sensei.waiting.run);
    check(guest.mirai.sensei.deferral.run);
    check(guest.mirai.sensei.population.run);
    check(guest.mirai.sensei.width.run);
    serial.printf(retentionlabels.GROUP, .{});
    check(guest.mirai.kata.retention.run);
    check(guest.mirai.kata.race.run);
    serial.printf(retentionlabels.GROUP_POPULATION, .{});
    check(guest.mirai.kata.population.run);
    serial.printf(labels.GROUP_LIFECYCLE, .{});
    check(guest.mirai.kata.lifecycle.run);
    serial.printf(labels.GROUP_COMPLETION, .{});
    check(guest.mirai.kata.completion.run);
    serial.printf(accesslabels.GROUP, .{});
    check(guest.mirai.user.access.run);
    serial.printf(labels.GROUP_PERSONA, .{});
    check(guest.mirai.thread.persona.run);
    serial.printf(invocationlabels.GROUP, .{});
    check(guest.mirai.invocations.query.run);
    check(guest.mirai.invocations.state.run);
    serial.printf(completionlabels.GROUP, .{});
    check(guest.mirai.invocations.completion.run.run);
    serial.printf(labels.GROUP_TERMINATION, .{});
    check(guest.mirai.invocations.termination.run);
    serial.printf(postmanlabels.GROUP, .{});
    check(guest.mirai.postman.scenarios.run);
    serial.printf(contextlabels.GROUP, .{});
    check(guest.mirai.thread.construction.run);
    check(guest.mirai.thread.context.run);
    serial.printf(crimsonlabels.GROUP, .{});
    @call(.never_inline, guest.mirai.crimson.codec.run, .{});
    @call(.never_inline, guest.mirai.crimson.ports.run, .{});
    @call(.never_inline, guest.mirai.crimson.corpse.run, .{});
    serial.printf(labels.COMPLETE, .{verify.count()});
}

fn check(comptime subject: anytype) void {
    @call(.never_inline, subject, .{}) catch |failure| verify.failure(failure);
}
