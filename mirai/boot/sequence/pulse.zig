//! Start Pulse In Ordinary Boot On Supported Native Storage

const launch = @import("mirai").bootstrap.pulse.launch;
const messages = @import("mirai").boot.strings.sequence.messages;
const print = @import("mirai").boot.sequence.print;
const scheduler = @import("mirai").sensei.run;

const BootInfo = @import("mirai").boot.types.sequence.info.BootInfo;
const PulseBootError = @import("mirai").boot.errors.sequence.pulse.PulseBootError;

pub fn activate(info: *const BootInfo) !void {
    if (info.Transport != .Sata) {
        print.log(messages.LINE, .{messages.PULSE_SKIPPED});
        return;
    }
    const volume = info.Volume orelse return PulseBootError.BootVolumeMissing;
    const prepared = try launch.start(volume);
    try scheduler.yield();
    if (!prepared.Thread.Started or prepared.Thread.Mode != .Persona) return PulseBootError.PulseDidNotEnterPersona;
    print.log(messages.LINE, .{messages.PULSE_ENTERED});
}
