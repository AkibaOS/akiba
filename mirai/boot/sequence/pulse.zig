//! Start Pulse In Ordinary Boot On Supported Native Storage

const afs = @import("mirai").bootstrap.driver.afs;
const ahci = @import("mirai").device.ahci.authority;
const collapse = @import("mirai").crimson.panic.collapse;
const halt = @import("asm").cpu.halt;
const launch = @import("mirai").bootstrap.pulse.launch;
const messages = @import("mirai").boot.strings.sequence.messages;
const print = @import("mirai").boot.sequence.print;
const scheduler = @import("mirai").sensei.run;
const status = @import("mirai").boot.strings.sequence.status;
const weaver = @import("mirai").bootstrap.weaver.handoff;

const BootInfo = @import("mirai").boot.types.sequence.info.BootInfo;
const PulseBootError = @import("mirai").boot.errors.sequence.pulse.PulseBootError;
const StorageError = @import("mirai").bootstrap.errors.storage.read.StorageError;

pub fn activate(info: *const BootInfo) !void {
    if (info.Transport != .Sata) {
        print.log(messages.LINE, .{messages.PULSE_SKIPPED});
        return;
    }
    const volume = info.Volume orelse return PulseBootError.BootVolumeMissing;
    const prepared = try launch.start(volume);
    try scheduler.yield();
    while (weaver.startupState(prepared.ID) == null) {
        try scheduler.yield();
        if (weaver.startupState(prepared.ID) == null) halt.waitForInterrupt();
    }
    if (!weaver.startupFinished(prepared.ID)) return PulseBootError.ServiceStartupFailed;
    if (!prepared.Thread.Started or prepared.Thread.Mode != .Persona) return PulseBootError.PulseDidNotEnterPersona;
    if (!weaver.readyFor(prepared.ID)) return PulseBootError.WeaverNotReady;
    if (!ahci.ready(prepared.ID)) return PulseBootError.AhciDriverNotReady;
    if (!afs.ready(prepared.ID)) return PulseBootError.AfsDriverNotReady;
    print.log(messages.LINE, .{messages.PULSE_ENTERED});
    print.log(messages.LINE, .{messages.WEAVER_READY});
}

pub fn fail(failure: anyerror) noreturn {
    print.log(messages.PULSE_FAILED, .{@errorName(failure)});
    if (failure == StorageError.BootUnitMissing) {
        print.fail(status.ERROR_PULSE_MISSING);
        collapse.collapse(status.ERROR_PULSE_MISSING, null);
    }
    print.fail(status.ERROR_PULSE);
    halt.haltLoop();
}
