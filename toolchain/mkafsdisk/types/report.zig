//! Published Disk Image Statistics And Stream Trailer

const std = @import("std");

pub const Esp = struct {
    Clusters: u32,
    BootloaderBytes: u64,
    BootloaderClusters: u32,
};

pub const Report = struct {
    SizeBytes: u64,
    EspFirstSector: u64,
    EspLastSector: u64,
    AfsFirstSector: u64,
    AfsLastSector: u64,
    BootloaderBytes: u64,
    EspClusters: u32,
    BootloaderClusters: u32,
    Units: u32,
    Stacks: u32,
    CellBytes: u32,
    TotalCells: u32,
    FreeCells: u32,

    pub const BYTES = size: {
        var length = 0;
        for (std.meta.fields(Report)) |field| length += @sizeOf(field.type);
        break :size length;
    };

    pub fn encode(self: Report) [BYTES]u8 {
        var bytes: [BYTES]u8 = undefined;
        var offset: usize = 0;
        inline for (std.meta.fields(Report)) |field| {
            const size = @sizeOf(field.type);
            std.mem.writeInt(field.type, bytes[offset..][0..size], @field(self, field.name), .little);
            offset += size;
        }
        return bytes;
    }

    pub fn decode(bytes: *const [BYTES]u8) Report {
        var report: Report = undefined;
        var offset: usize = 0;
        inline for (std.meta.fields(Report)) |field| {
            const size = @sizeOf(field.type);
            @field(report, field.name) = std.mem.readInt(field.type, bytes[offset..][0..size], .little);
            offset += size;
        }
        return report;
    }
};
