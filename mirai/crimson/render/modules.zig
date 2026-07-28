//! Render Loaded Modules

const constants = @import("mirai").crimson.constants;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const limits = constants.limits;
const messages = strings.messages;

const ModuleInfo = types.module.ModuleInfo;

var loaded_modules: [limits.MAX_MODULES]ModuleInfo = undefined;
var module_count: usize = 0;

pub fn registerModule(name: []const u8, base_address: u64, size: u64) bool {
    if (module_count >= limits.MAX_MODULES) {
        return false;
    }

    var module = &loaded_modules[module_count];
    const length = @min(name.len, limits.MODULE_NAME_CAPACITY - 1);
    @memcpy(module.Name[0..length], name[0..length]);
    module.Name[length] = 0;
    module.NameLength = length;
    module.BaseAddress = base_address;
    module.Size = size;

    module_count += 1;
    return true;
}

pub fn render() void {
    if (module_count == 0) {
        serial.write.printf(messages.MODULES_NONE, .{});
        return;
    }

    serial.write.printf(messages.MODULES_HEADER, .{});

    for (0..module_count) |index| {
        const module = &loaded_modules[index];
        serial.write.printf(messages.MODULE_ENTRY, .{
            module.Name[0..module.NameLength],
            module.BaseAddress,
            module.BaseAddress + module.Size,
            module.Size,
        });
    }

    serial.write.printf("\n", .{});
}

pub fn findModuleForAddress(address: u64) ?*const ModuleInfo {
    for (0..module_count) |index| {
        const module = &loaded_modules[index];
        if (address >= module.BaseAddress and address < module.BaseAddress + module.Size) {
            return module;
        }
    }
    return null;
}

pub fn clearModules() void {
    module_count = 0;
}
