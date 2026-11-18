//! Pre Activation Owned Root Allocation Rollback Checks

const std = @import("std");

const allocation = @import("tests").guest.support.allocation;
const cpu = @import("asm").cpu;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.tables;
const pmm = @import("mirai").pmm;
const types = @import("mirai").boot.types;
const zones = @import("mirai").memory.zone.bootstrap;

const BootInfo = types.sequence.info.BootInfo;

var completed: bool = false;

pub fn checkZoneRollback() void {
    defer allocation.clear();
    const before = pmm.state.getStatistics();
    const search_start = pmm.state.getState().SearchStart;
    for (0..2) |budget| {
        allocation.arm(budget);
        if (zones.init()) |_| {
            @panic(labels.ZONE_SEED_ROLLBACK);
        } else |failure| {
            if (failure != error.OutOfMemory or zones.isInitialized() or
                !std.meta.eql(before, pmm.state.getStatistics()) or search_start != pmm.state.getState().SearchStart)
                @panic(labels.ZONE_SEED_ROLLBACK);
        }
    }
}

pub fn run(info: *const BootInfo) void {
    defer allocation.clear();
    completed = false;
    const warm = kagami.bootstrap.prepare(info) catch @panic(labels.EARLY_FAILURE);
    allocation.arm(0);
    kagami.bootstrap.abort(warm);
    allocation.clear();
    const before = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    const previous = cpu.control.readCR3();
    var failures: usize = 0;
    while (true) : (failures += 1) {
        allocation.arm(failures);
        if (kagami.bootstrap.prepare(info)) |prepared| {
            allocation.arm(0);
            const valid = prepared.TableCount == prepared.Kagami.TablePages and
                prepared.TableCount != 0 and prepared.StackCount != 0 and kagami.tables.ownership.reset(&prepared.Kagami);
            kagami.bootstrap.abort(prepared);
            allocation.clear();
            if (!valid or failures <= 2 or prepared.Phase != .Empty or prepared.TableCount != 0 or prepared.StackCount != 0 or
                prepared.Kagami.Frames != null or prepared.Kagami.TablePages != 0 or
                previous != cpu.control.readCR3() or search != pmm.state.getState().SearchStart or
                !std.meta.eql(before, pmm.state.getStatistics())) @panic(labels.EARLY_FAILURE);
            completed = true;
            return;
        } else |failure| {
            allocation.clear();
            if (failure != error.OutOfMemory or previous != cpu.control.readCR3() or search != pmm.state.getState().SearchStart or
                !std.meta.eql(before, pmm.state.getStatistics())) @panic(labels.EARLY_FAILURE);
        }
    }
}

pub fn passed() bool {
    return completed;
}
