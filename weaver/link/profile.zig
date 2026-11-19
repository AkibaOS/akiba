//! Supported Native Dynamic Linking Metadata

const elf = @import("shared").elf;

const LinkError = @import("weaver").link.errors.link.LinkError;
const Metadata = elf.types.dynamic.Metadata;
const Role = elf.types.dynamic.Role;
const dynamic = elf.constants.dynamic;

pub fn check(metadata: Metadata, role: Role) LinkError!void {
    const allowed_extra = dynamic.EXTRA_NOW | if (role == .Executable) dynamic.EXTRA_PIE else 0;
    for (metadata.Entries) |entry| {
        switch (entry.Tag) {
            dynamic.NEEDED, dynamic.PLT_RELOCATION_BYTES, dynamic.PROCEDURE_TABLE, dynamic.HASH, dynamic.STRING_TABLE, dynamic.SYMBOL_TABLE, dynamic.RELA, dynamic.RELA_BYTES, dynamic.RELA_ENTRY_BYTES, dynamic.STRING_BYTES, dynamic.SYMBOL_ENTRY_BYTES, dynamic.SONAME, dynamic.PLT_RELOCATION_KIND, dynamic.JUMP_RELOCATIONS, dynamic.GNU_HASH => {},
            dynamic.DEBUG, dynamic.BIND_NOW => if (entry.Value != 0) return error.UnsupportedLinkMetadata,
            dynamic.FLAGS => if (entry.Value & ~dynamic.FLAG_BIND_NOW != 0) return error.UnsupportedLinkMetadata,
            dynamic.FLAGS_EXTRA => if (entry.Value & ~allowed_extra != 0) return error.UnsupportedLinkMetadata,
            dynamic.RELATIVE_COUNT => try checkRelativePrefix(metadata, entry.Value),
            else => return error.UnsupportedLinkMetadata,
        }
    }
}

fn checkRelativePrefix(metadata: Metadata, count: u64) LinkError!void {
    if (count > metadata.Relocations.len) return error.UnsupportedLinkMetadata;
    for (metadata.Relocations[0..@intCast(count)]) |entry| {
        if (entry.Info != elf.constants.relocation.RELATIVE) return error.UnsupportedLinkMetadata;
    }
}
