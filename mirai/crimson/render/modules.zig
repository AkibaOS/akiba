//! Bounded Diagnostic Module Registry

const std = @import("std");

const constants = @import("mirai").crimson.constants;
const text = @import("utils").text;
const types = @import("mirai").crimson.types;

const limits = constants.limits;

const ModuleInfo = types.module.ModuleInfo;

var loaded_modules: [limits.MAX_MODULES]ModuleInfo = undefined;
var module_count: usize = 0;

pub fn registerModule(name: []const u8, base_address: u64, size: u64) bool {
    if (name.len >= limits.MODULE_NAME_CAPACITY or module_count >= limits.MAX_MODULES or
        size > std.math.maxInt(u64) - base_address)
    {
        return false;
    }

    var module = &loaded_modules[module_count];
    const length = text.ascii.copyBounded(module.Name[0 .. limits.MODULE_NAME_CAPACITY - 1], name);
    module.Name[length] = 0;
    module.NameLength = length;
    module.BaseAddress = base_address;
    module.Size = size;

    module_count += 1;
    return true;
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
