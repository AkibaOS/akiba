//! EFI Diagnostic Menu Input

const efi = @import("hikari").efi;
const limits = @import("menu").constants.limits;
const phase = @import("tests").phase;
const serial = @import("menu").serial;

const Action = phase.types.action.Action;
const BootServices = efi.types.services.boot.BootServices;
const Event = efi.types.base.Event;
const Input = efi.types.protocols.input.SimpleTextInputProtocol;
const status = efi.constants.status;

pub fn readyAndWait(services: *BootServices, input: *Input, epoch: u64) !Action {
    const armed = phase.menu.encodeArmed(epoch);
    if (!serial.send(services, &armed)) return error.MenuArmedTransmissionFailed;
    const events = [_]Event{input.WaitForKey};
    while (true) {
        var index: usize = events.len;
        if (services.WaitForEvent(events.len, &events, &index) != status.SUCCESS) return error.MenuEventWaitFailed;
        if (index != 0) return error.MenuWrongEventIndex;
        var key: efi.types.input.InputKey = undefined;
        switch (input.ReadKeyStroke(input, &key)) {
            status.SUCCESS => {},
            status.NOT_READY => continue,
            else => return error.MenuInputReadFailed,
        }
        if (key.ScanCode != limits.NO_SCAN_CODE) continue;
        switch (key.UnicodeChar) {
            limits.ENTER => return .Boot,
            limits.SHUTDOWN_LOWER, limits.SHUTDOWN_UPPER => return .Shutdown,
            else => continue,
        }
    }
}
