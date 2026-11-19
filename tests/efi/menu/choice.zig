//! EFI Diagnostic Menu Input

const display = @import("tests").efi.menu.display;
const efi = @import("hikari").efi;
const limits = @import("tests").efi.constants.menu.limits;
const phase = @import("tests").phase;
const serial = @import("tests").efi.menu.serial;

const Action = phase.types.action.Action;
const BootServices = efi.types.services.boot.BootServices;
const Input = @import("tests").efi.keyboard.Input;
const View = @import("tests").efi.types.menu.display.View;
const status = efi.constants.status;

pub fn readyAndWait(services: *BootServices, input: *Input, epoch: u64, view: *View) !Action {
    const armed = phase.menu.encodeArmed(epoch);
    if (!serial.send(services, &armed)) return error.MenuArmedTransmissionFailed;
    var tick: phase.types.menu.CountdownFrame = undefined;
    var received: usize = 0;
    var previous = phase.constants.menu.COUNTDOWN_SECONDS;
    while (true) {
        if (try readAction(input)) |action| return action;
        received += try serial.receiveAvailable(tick[received..]);
        if (received == tick.len) {
            received = 0;
            if (phase.menu.decodeCountdown(&tick, epoch, previous)) |seconds| {
                if (!display.updateCountdown(view, seconds)) return error.MenuCountdownRenderFailed;
                previous = seconds;
            }
            continue;
        }
        if (services.Stall(limits.INPUT_POLL_MICROSECONDS) != status.SUCCESS) return error.MenuInputStallFailed;
    }
}

fn readAction(input: *Input) !?Action {
    var key: efi.types.input.InputKey = undefined;
    switch (input.ReadKeyStroke(input, &key)) {
        status.SUCCESS => {},
        status.NOT_READY => return null,
        else => return error.MenuInputReadFailed,
    }
    if (key.ScanCode != limits.NO_SCAN_CODE) return null;
    return switch (key.UnicodeChar) {
        limits.ENTER => .Boot,
        limits.SHUTDOWN_LOWER, limits.SHUTDOWN_UPPER => .Shutdown,
        else => null,
    };
}
