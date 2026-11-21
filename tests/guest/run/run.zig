//! Explicit Guest Regression Execution

const std = @import("std");

const bootstrapwire = @import("tests").phase.strings.bootstrap;
const cancellation = @import("tests").guest.support.cancellation;
const grouptext = @import("tests").phase.strings.groups;
const guest = @import("tests").guest;
const inputwire = @import("tests").phase.strings.input;
const labels = @import("tests").guest.strings.guest;
const live = @import("tests").phase.constants.live.frame;
const markers = @import("tests").phase.strings.serial;
const metadata = @import("tests").machine.constants.config.directory;
const scenariolabels = @import("tests").phase.strings.scenario;
const schedule = @import("tests").phase.strings.schedule;
const screen = @import("tests").guest.screen.control;
const screentext = @import("tests").screen.strings.text;
const screenview = @import("tests").screen.live;
const serial = @import("mirai").drivers.serial.write;
const verify = @import("tests").guest.support.verify;
const LiveOffer = @import("tests").phase.types.live.frames.Offer;
const Scenario = @import("tests").phase.types.scenario.Scenario;

const groups = .{
    .{ grouptext.ACQUISITION_GROUP, .{ guest.disk.gpt.run, guest.disk.fat.run, guest.disk.reader.run, guest.disk.unit.run } },
    .{ grouptext.HIKARI_GROUP_ELF, .{guest.loader.validation.run} },
    .{ grouptext.HIKARI_GROUP_EFI, .{guest.efi.buffer.run} },
    .{ grouptext.BOOT_GROUP, .{ guest.boot.invariants.run, guest.boot.regions.run } },
    .{ grouptext.MEMORY_GROUP_PMM, .{ guest.pmm.frames.run, guest.pmm.ranges.run, guest.pmm.reservation.run, guest.pmm.sparse.run } },
    .{ grouptext.MEMORY_GROUP_KERNEL, .{
        guest.memory.allocation.run,  guest.memory.range.run,     guest.memory.heap.run,
        guest.memory.validation.run,  guest.memory.allocator.run, guest.memory.zone.run,
        guest.memory.growth.run,      guest.memory.validity.run,  guest.memory.failure.run,
        guest.memory.pool.run,        guest.memory.stack.run,     guest.memory.reuse.run,
        guest.memory.reservation.run,
    } },
    .{ grouptext.MEMORY_GROUP_KAGAMI, .{
        guest.kagami.mapping.run,  guest.kagami.ownership.run,  guest.kagami.rejection.run,
        guest.kagami.validity.run, guest.kagami.effective.run,  guest.kagami.failure.run,
        guest.kagami.graph.run,    guest.kagami.population.run, guest.kagami.alias.run,
    } },
    .{ grouptext.MEMORY_GROUP_OWNED, .{ guest.user.regressions.run, guest.user.population.run, guest.user.failure.run } },
    .{ grouptext.GUEST_GROUP_MEMORY, .{ guest.user.memory.run, guest.user.sharing.run, guest.user.reference.run } },
    .{ grouptext.ELF_GROUP, .{
        guest.bootstrap.image.run,   guest.bootstrap.rejection.run,    guest.bootstrap.pressure.run,
        guest.bootstrap.growth.run,  guest.bootstrap.finalization.run, guest.bootstrap.order.run,
        guest.bootstrap.startup.run, guest.bootstrap.execution.run,    guest.bootstrap.dynamic.run,
    } },
    .{ grouptext.SENSEI_GROUP, .{ guest.sensei.admission.run, guest.sensei.waiting.run, guest.sensei.deferral.run, guest.sensei.population.run, guest.sensei.width.run } },
    .{ grouptext.RETENTION_GROUP, .{ guest.kata.retention.run, guest.kata.race.run } },
    .{ grouptext.RETENTION_GROUP_POPULATION, .{guest.kata.population.run} },
    .{ grouptext.GUEST_GROUP_LIFECYCLE, .{ guest.kata.destruction.run, guest.kata.lifecycle.run } },
    .{ grouptext.GUEST_GROUP_COMPLETION, .{guest.kata.completion.run} },
    .{ grouptext.ACCESS_GROUP, .{guest.user.access.run} },
    .{ grouptext.GUEST_GROUP_PERSONA, .{guest.thread.persona.run} },
    .{ grouptext.INVOCATIONS_GROUP, .{ guest.invocations.query.run, guest.invocations.state.run } },
    .{ grouptext.COMPLETION_GROUP, .{guest.completion.run.run} },
    .{ grouptext.GUEST_GROUP_TERMINATION, .{guest.invocations.termination.run} },
    .{ grouptext.POSTMAN_GROUP, .{guest.postman.scenarios.run} },
    .{ grouptext.CONTEXT_GROUP, .{ guest.thread.construction.run, guest.thread.context.run } },
    .{ grouptext.CRIMSON_GROUP, .{ guest.crimson.codec.run, guest.crimson.ports.run, guest.crimson.corpse.run, guest.crimson.modules.run } },
};

comptime {
    if (groups.len + 1 != live.STANDARD_UNITS) @compileError(labels.SCHEDULE_MISMATCH);
    for (groups, 0..) |group, index| {
        if (!std.mem.eql(u8, group[0], schedule.GROUPS[index])) @compileError(labels.SCHEDULE_MISMATCH);
    }
}

pub fn execute() bool {
    serial.printf(markers.BEGIN_LINE, .{});
    switch (guest.support.selector.selected()) {
        .Standard => return standard(),
        .Collapse => @call(.never_inline, guest.crimson.fatal.run, .{}),
        .Firmware => @panic(scenariolabels.INVALID),
        .Devices => {
            const owned = screen.isActive();
            defer screen.release();
            serial.printf(inputwire.GROUP, .{});
            if (guest.ahci.run.enabled() catch |failure| verify.failure(failure)) {
                check(guest.ahci.run.run);
            } else {
                @call(.never_inline, guest.drivers.input.run, .{});
            }
            screen.checkpoint();
            serial.printf(markers.COMPLETE_FORMAT, .{verify.count()});
            return owned;
        },
        .PulseDeath => {
            check(guest.kata.fatal.run);
            return false;
        },
    }
}

pub fn beginPhase(selected: Scenario) void {
    const prior = guest.support.phase.context();
    if (selected != .Standard and prior == null) return;
    const cancel_ready = selected == .Standard and cancellation.enable();
    if (startScreen(groups.len + 1, cancel_ready, prior)) {
        screen.begin(if (selected == .Standard) screentext.BOOTSTRAP_ROLLBACK else screenview.name(selected));
        if (prior != null) serial.printf(markers.DISPLAY_READY, .{});
    } else if (prior != null) {
        @panic(labels.DISPLAY_FAILED);
    }
}

pub fn finishBootstrap() void {
    screen.finish(.Pass);
}

fn startScreen(total: usize, cancel_ready: bool, prior: ?LiveOffer) bool {
    if (prior) |context| return screen.start(total, &context.Date, cancel_ready, context);
    var date_buffer: [metadata.MAX_VALUE_BYTES]u8 = undefined;
    return screen.start(total, guest.support.selector.buildDate(&date_buffer), cancel_ready, null);
}

fn standard() bool {
    const owned = screen.isActive() or startScreen(groups.len, cancellation.enabled(), null);
    defer screen.release();
    inline for (groups, 1..) |group, ordinal| {
        const title = group[0][markers.GROUP.len .. group[0].len - 1];
        screen.begin(title);
        serial.printf(group[0], .{});
        inline for (group[1]) |subject| {
            cancellation.checkpoint();
            check(subject);
            cancellation.checkpoint();
            screen.checkpoint();
        }
        screen.finish(.Pass);
        serial.printf(bootstrapwire.STANDARD_GROUP_COMPLETE, .{@as(usize, ordinal)});
    }
    cancellation.finish();
    screen.complete();
    serial.printf(markers.COMPLETE_FORMAT, .{verify.count()});
    return owned;
}

fn check(comptime subject: anytype) void {
    if (@typeInfo(@TypeOf(subject)).@"fn".return_type.? == void) {
        @call(.never_inline, subject, .{});
    } else {
        @call(.never_inline, subject, .{}) catch |failure| verify.failure(failure);
    }
}
