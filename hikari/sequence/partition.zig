//! Hikari AFS Partition Locator

const efi = @import("../efi/efi.zig");
const disk = @import("../disk/disk.zig");

pub const PartitionInfo = struct {
    block_io: *efi.protocols.BlockIoProtocol,
    start_lba: u64,
};

pub fn find_afs_partition(boot_services: *efi.services.BootServices) ?PartitionInfo {
    var handle_count: usize = 0;
    var handles: [*]efi.types.Handle = undefined;

    const status = boot_services.locate_handle_buffer(
        .by_protocol,
        &efi.constants.guids.block_io_protocol,
        null,
        &handle_count,
        &handles,
    );

    if (efi.types.is_error(status)) {
        return null;
    }

    var index: usize = 0;
    while (index < handle_count) : (index += 1) {
        var block_io: ?*anyopaque = null;
        const bio_status = boot_services.handle_protocol(
            handles[index],
            &efi.constants.guids.block_io_protocol,
            &block_io,
        );

        if (efi.types.is_error(bio_status)) {
            continue;
        }

        const bio: *efi.protocols.BlockIoProtocol = @ptrCast(@alignCast(block_io));

        if (bio.media.logical_partition) {
            continue;
        }

        var gpt_parser = disk.gpt.Parser.initialize(bio, boot_services) catch {
            continue;
        };

        const afs_part = gpt_parser.find_partition_by_type(efi.constants.guids.gpt_partition_type_akiba_afs);
        if (afs_part) |part| {
            return PartitionInfo{
                .block_io = bio,
                .start_lba = part.starting_lba,
            };
        }
    }

    return null;
}
