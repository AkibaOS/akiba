//! Decode A Supported Terminal SATA Node In A Complete Device Path

const std = @import("std");

const fields = @import("shared").boot.constants.device.path;

const Transport = @import("shared").boot.types.transport.Transport;

pub fn decode(bytes: []const u8) Transport {
    var remainder = bytes[0..@min(bytes.len, fields.LIMIT)];
    var seen_node = false;
    var preceding_pci = false;
    var seen_sata = false;
    var terminal_sata = false;
    while (remainder.len >= fields.HEADER_BYTES) {
        const kind = remainder[fields.TYPE_OFFSET];
        const subtype = remainder[fields.SUBTYPE_OFFSET];
        const length = std.mem.readInt(u16, remainder[fields.LENGTH_OFFSET..][0..@sizeOf(u16)], .little);
        if (length < fields.HEADER_BYTES or length > remainder.len) return .Unknown;
        if (kind == fields.END) {
            if (!seen_node or subtype != fields.END_ENTIRE or length != fields.HEADER_BYTES) return .Unknown;
            return if (terminal_sata) .Sata else .Other;
        }
        const pci = kind == fields.HARDWARE and subtype == fields.PCI;
        const sata = kind == fields.MESSAGING and subtype == fields.SATA;
        if ((pci and length != fields.PCI_BYTES) or (sata and (seen_sata or length != fields.SATA_BYTES))) return .Unknown;
        terminal_sata = sata and preceding_pci;
        preceding_pci = pci;
        seen_sata = seen_sata or sata;
        seen_node = true;
        remainder = remainder[length..];
    }
    return .Unknown;
}
