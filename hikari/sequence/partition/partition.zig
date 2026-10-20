//! Hikari AFS Partition Locator

const disk = @import("hikari").disk;
const efi = @import("hikari").efi;
const types = @import("hikari").sequence.types;

const PartitionInfo = types.partition.PartitionInfo;

pub fn findAfsPartition(boot_services: *efi.types.services.boot.BootServices) ?PartitionInfo {
    var handle_count: usize = 0;
    var handles: [*]efi.types.base.Handle = undefined;

    const status = boot_services.LocateHandleBuffer(
        .ByProtocol,
        &efi.constants.guids.BLOCK_IO_PROTOCOL,
        null,
        &handle_count,
        &handles,
    );

    if (efi.status.isError(status)) {
        return null;
    }

    defer _ = boot_services.FreePool(@ptrCast(handles));

    var index: usize = 0;
    while (index < handle_count) : (index += 1) {
        var block_io: ?*anyopaque = null;
        const block_io_status = boot_services.HandleProtocol(
            handles[index],
            &efi.constants.guids.BLOCK_IO_PROTOCOL,
            &block_io,
        );

        if (efi.status.isError(block_io_status)) {
            continue;
        }

        const block_io_protocol: *efi.types.protocols.block.BlockIoProtocol = @ptrCast(@alignCast(block_io));

        if (block_io_protocol.Media.LogicalPartition) {
            continue;
        }

        var gpt_parser = disk.types.parser.Parser.initialize(block_io_protocol, boot_services) catch {
            continue;
        };

        defer gpt_parser.deinitialize();
        const afs_partition = gpt_parser.findPartitionByType(efi.constants.guids.GPT_PARTITION_TYPE_AKIBA_AFS);
        if (afs_partition) |partition| {
            return PartitionInfo{
                .BlockIO = block_io_protocol,
                .StartLBA = partition.StartingLBA,
                .EndLBA = partition.EndingLBA,
            };
        }
    }

    return null;
}
