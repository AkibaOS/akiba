//! Classify Ports Without Treating Unknown Devices As Empty

const fields = @import("shared").ahci.constants.discover.port;

const Kind = @import("shared").ahci.types.discover.port.Kind;

pub fn needsReceive(link: u32, signature: u32) bool {
    return link & fields.PRESENCE_MASK == fields.ESTABLISHED and link & fields.POWER_MASK == fields.ACTIVE and signature == fields.INITIAL_SIGNATURE;
}

pub fn classify(link: u32, signature: u32) Kind {
    const presence = link & fields.PRESENCE_MASK;
    if (presence == fields.NO_DEVICE) return .Empty;
    if (presence != fields.ESTABLISHED or link & fields.POWER_MASK != fields.ACTIVE) return .Unverifiable;
    return switch (signature) {
        fields.ATA_SIGNATURE => .AtaDisk,
        fields.PACKET_SIGNATURE => .PacketDevice,
        else => .Unverifiable,
    };
}
