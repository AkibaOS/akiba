//! Hikari AFS Partition Locator

const disk = @import("../../disk/disk.zig");
const efi = @import("../../efi/efi.zig");

pub const PartitionInfo = struct {
    BlockIO: *efi.protocols.block.BlockIoProtocol,
    StartLBA: u64,
};

pub fn findAfsPartition(boot_services: *efi.services.boot.BootServices) ?PartitionInfo {
    var handle_count: usize = 0;
    var handles: [*]efi.types.base.Handle = undefined;

    const status = boot_services.LocateHandleBuffer(
        .ByProtocol,
        &efi.constants.guids.BLOCK_IO_PROTOCOL,
        null,
        &handle_count,
        &handles,
    );

    if (efi.types.base.isError(status)) {
        return null;
    }

    var index: usize = 0;
    while (index < handle_count) : (index += 1) {
        var block_io: ?*anyopaque = null;
        const block_io_status = boot_services.HandleProtocol(
            handles[index],
            &efi.constants.guids.BLOCK_IO_PROTOCOL,
            &block_io,
        );

        if (efi.types.base.isError(block_io_status)) {
            continue;
        }

        const block_io_protocol: *efi.protocols.block.BlockIoProtocol = @ptrCast(@alignCast(block_io));

        if (block_io_protocol.Media.LogicalPartition) {
            continue;
        }

        var gpt_parser = disk.gpt.parser.Parser.initialize(block_io_protocol, boot_services) catch {
            continue;
        };

        const afs_partition = gpt_parser.findPartitionByType(efi.constants.guids.GPT_PARTITION_TYPE_AKIBA_AFS);
        if (afs_partition) |partition| {
            return PartitionInfo{
                .BlockIO = block_io_protocol,
                .StartLBA = partition.StartingLBA,
            };
        }
    }

    return null;
}
