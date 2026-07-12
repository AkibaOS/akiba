//! Hikari Menu Input

const efi = @import("../../efi/efi.zig");

pub const InputAction = enum {
    None,
    Up,
    Down,
    Select,
    Cancel,
    PageUp,
    PageDown,
    Home,
    End,
};

pub const Input = struct {
    SystemTable: *efi.services.system.SystemTable,

    pub fn initialize(system_table: *efi.services.system.SystemTable) Input {
        return Input{
            .SystemTable = system_table,
        };
    }

    pub fn poll(self: *Input) InputAction {
        var key: efi.types.input.InputKey = undefined;
        const status = self.SystemTable.ConsoleInput.ReadKeyStroke(
            self.SystemTable.ConsoleInput,
            &key,
        );

        if (efi.types.base.isError(status)) {
            return .None;
        }

        if (key.ScanCode != 0) {
            return switch (key.ScanCode) {
                efi.constants.keyboard.SCAN_UP => .Up,
                efi.constants.keyboard.SCAN_DOWN => .Down,
                efi.constants.keyboard.SCAN_ESCAPE => .Cancel,
                efi.constants.keyboard.SCAN_PAGE_UP => .PageUp,
                efi.constants.keyboard.SCAN_PAGE_DOWN => .PageDown,
                efi.constants.keyboard.SCAN_HOME => .Home,
                efi.constants.keyboard.SCAN_END => .End,
                else => .None,
            };
        }

        if (key.UnicodeChar != 0) {
            return switch (key.UnicodeChar) {
                '\r', ' ' => .Select,
                'j', 'J' => .Down,
                'k', 'K' => .Up,
                'q', 'Q' => .Cancel,
                else => .None,
            };
        }

        return .None;
    }

    pub fn waitForKey(self: *Input) void {
        var index: usize = 0;
        const events = [_]efi.types.base.Event{self.SystemTable.ConsoleInput.WaitForKey};
        _ = self.SystemTable.BootServices.WaitForEvent(1, &events, &index);
    }

    pub fn waitForAction(self: *Input) InputAction {
        while (true) {
            const action = self.poll();
            if (action != .None) {
                return action;
            }
            self.waitForKey();
        }
    }

    pub fn clearInputBuffer(self: *Input) void {
        while (self.poll() != .None) {}
    }
};
