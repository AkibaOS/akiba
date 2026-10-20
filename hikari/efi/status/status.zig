//! Hikari EFI Status Operations

const constants = @import("hikari").efi.constants.status;

const Status = @import("hikari").efi.types.base.Status;

pub fn isError(status: Status) bool {
    return (status >> (@bitSizeOf(Status) - 1)) == 1;
}

pub fn isSuccess(status: Status) bool {
    return status == constants.SUCCESS;
}
