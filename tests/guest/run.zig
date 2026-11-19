//! Explicit Guest Regression Execution

const accesslabels = @import("tests").strings.access;
const acquisitionlabels = @import("tests").strings.acquisition;
const bootlabels = @import("tests").strings.boot;
const cancellation = @import("tests").guest.support.cancellation;
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
const metadata = @import("tests").constants.scenario;
const postmanlabels = @import("tests").strings.postman;
const retentionlabels = @import("tests").strings.retention;
const runnerlabels = @import("tests").strings.runner;
const scenariolabels = @import("tests").strings.scenario;
const screen = @import("tests").guest.screen.control;
const screentext = @import("tests").screen.strings.text;
const senseilabels = @import("tests").strings.sensei;
const serial = @import("mirai").drivers.serial.write;
const verify = @import("tests").verify;

const groups = .{
    .{ acquisitionlabels.GROUP, .{ guest.hikari.disk.gpt.run, guest.hikari.disk.fat.run, guest.hikari.disk.reader.run, guest.hikari.disk.unit.run } },
    .{ hikarilabels.GROUP_ELF, .{guest.hikari.loader.validation.run} },
    .{ hikarilabels.GROUP_EFI, .{guest.hikari.efi.buffer.run} },
    .{ bootlabels.GROUP, .{ guest.mirai.boot.invariants.run, guest.mirai.boot.regions.run } },
    .{ memorylabels.GROUP_PMM, .{ guest.mirai.pmm.frames.run, guest.mirai.pmm.ranges.run, guest.mirai.pmm.reservation.run, guest.mirai.pmm.sparse.run } },
    .{ memorylabels.GROUP_KERNEL, .{
        guest.mirai.memory.allocation.run,  guest.mirai.memory.range.run,     guest.mirai.memory.heap.run,
        guest.mirai.memory.validation.run,  guest.mirai.memory.allocator.run, guest.mirai.memory.zone.run,
        guest.mirai.memory.growth.run,      guest.mirai.memory.validity.run,  guest.mirai.memory.failure.run,
        guest.mirai.memory.pool.run,        guest.mirai.memory.stack.run,     guest.mirai.memory.reuse.run,
        guest.mirai.memory.reservation.run,
    } },
    .{ memorylabels.GROUP_KAGAMI, .{
        guest.mirai.kagami.mapping.run,  guest.mirai.kagami.ownership.run,  guest.mirai.kagami.rejection.run,
        guest.mirai.kagami.validity.run, guest.mirai.kagami.effective.run,  guest.mirai.kagami.failure.run,
        guest.mirai.kagami.graph.run,    guest.mirai.kagami.population.run, guest.mirai.kagami.alias.run,
    } },
    .{ memorylabels.GROUP_OWNED, .{ guest.mirai.user.regressions.run, guest.mirai.user.population.run, guest.mirai.user.failure.run } },
    .{ labels.GROUP_MEMORY, .{guest.mirai.user.memory.run} },
    .{ elflabels.GROUP, .{
        guest.mirai.bootstrap.image.run,     guest.mirai.bootstrap.rejection.run,    guest.mirai.bootstrap.pressure.run,
        guest.mirai.bootstrap.growth.run,    guest.mirai.bootstrap.finalization.run, guest.mirai.bootstrap.order.run,
        guest.mirai.bootstrap.execution.run,
    } },
    .{ senseilabels.GROUP, .{ guest.mirai.sensei.admission.run, guest.mirai.sensei.waiting.run, guest.mirai.sensei.deferral.run, guest.mirai.sensei.population.run, guest.mirai.sensei.width.run } },
    .{ retentionlabels.GROUP, .{ guest.mirai.kata.retention.run, guest.mirai.kata.race.run } },
    .{ retentionlabels.GROUP_POPULATION, .{guest.mirai.kata.population.run} },
    .{ labels.GROUP_LIFECYCLE, .{ guest.mirai.kata.destruction.run, guest.mirai.kata.lifecycle.run } },
    .{ labels.GROUP_COMPLETION, .{guest.mirai.kata.completion.run} },
    .{ accesslabels.GROUP, .{guest.mirai.user.access.run} },
    .{ labels.GROUP_PERSONA, .{guest.mirai.thread.persona.run} },
    .{ invocationlabels.GROUP, .{ guest.mirai.invocations.query.run, guest.mirai.invocations.state.run } },
    .{ completionlabels.GROUP, .{guest.mirai.invocations.completion.run.run} },
    .{ labels.GROUP_TERMINATION, .{guest.mirai.invocations.termination.run} },
    .{ postmanlabels.GROUP, .{guest.mirai.postman.scenarios.run} },
    .{ contextlabels.GROUP, .{ guest.mirai.thread.construction.run, guest.mirai.thread.context.run } },
    .{ crimsonlabels.GROUP, .{ guest.mirai.crimson.codec.run, guest.mirai.crimson.ports.run, guest.mirai.crimson.corpse.run, guest.mirai.crimson.modules.run } },
};

pub fn execute() bool {
    serial.printf(labels.BEGIN, .{});
    switch (guest.support.selector.selected()) {
        .Standard => return standard(),
        .Collapse => @call(.never_inline, guest.mirai.crimson.fatal.run, .{}),
        .Firmware => @panic(scenariolabels.INVALID),
        .Devices => {
            serial.printf(driverlabels.GROUP, .{});
            @call(.never_inline, guest.mirai.drivers.input.run, .{});
            serial.printf(labels.COMPLETE, .{verify.count()});
            return false;
        },
        .PulseDeath => {
            check(guest.mirai.kata.fatal.run);
            return false;
        },
    }
}

pub fn beginBootstrap() void {
    if (startScreen(groups.len + 1, cancellation.enable())) screen.begin(screentext.BOOTSTRAP_ROLLBACK);
}

pub fn finishBootstrap() void {
    screen.finish(.Pass);
}

fn startScreen(total: usize, cancel_ready: bool) bool {
    var date_buffer: [metadata.MAX_VALUE_BYTES]u8 = undefined;
    return screen.start(total, guest.support.selector.buildDate(&date_buffer), cancel_ready);
}

fn standard() bool {
    const owned = screen.isActive() or startScreen(groups.len, cancellation.enabled());
    defer screen.release();
    inline for (groups) |group| {
        const title = group[0][runnerlabels.GROUP_PREFIX.len .. group[0].len - 1];
        screen.begin(title);
        serial.printf(group[0], .{});
        inline for (group[1]) |subject| {
            cancellation.checkpoint();
            check(subject);
            cancellation.checkpoint();
            screen.checkpoint();
        }
        screen.finish(.Pass);
    }
    cancellation.finish();
    screen.complete();
    serial.printf(labels.COMPLETE, .{verify.count()});
    return owned;
}

fn check(comptime subject: anytype) void {
    if (@typeInfo(@TypeOf(subject)).@"fn".return_type.? == void) {
        @call(.never_inline, subject, .{});
    } else {
        @call(.never_inline, subject, .{}) catch |failure| verify.failure(failure);
    }
}
