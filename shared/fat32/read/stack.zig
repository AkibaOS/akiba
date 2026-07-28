//! FAT32 Stack Operations

const constants = @import("shared").fat32.constants;
const types = @import("shared").fat32.types;

const text = @import("utils").text;

const StackEntry = types.entry.StackEntry;

pub fn entryMatchesIdentity(entry: *const StackEntry, identity: []const u8) bool {
    var short_identity_buffer: [constants.sizes.SHORT_DISPLAY_LENGTH]u8 = undefined;
    const short_identity_length = entry.getShortIdentity(&short_identity_buffer);
    return text.ascii.equalsIgnoreCase(short_identity_buffer[0..short_identity_length], identity);
}
