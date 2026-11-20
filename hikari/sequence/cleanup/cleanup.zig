//! Bounded Cleanup Of A Pre-Exit Boot Attempt

const constants = @import("hikari").sequence.constants.memory;
const efi = @import("hikari").efi;
const handoff = @import("hikari").sequence.handoff;
const partition = @import("hikari").sequence.partition;
const types = @import("hikari").sequence.types.cleanup.claims;

pub fn releaseSource(claims: *types.Claims) bool {
    if (sealed(claims)) return false;
    return efi.buffer.releasePool(claims.Paging.BootServices, &claims.Source);
}

pub fn releaseReader(claims: *types.Claims) bool {
    if (sealed(claims)) return false;
    if (claims.Reader) |*reader| {
        if (!reader.deinitialize()) return false;
        claims.Reader = null;
    }
    return true;
}

fn releaseDiscovery(claims: *types.Claims) bool {
    if (claims.Discovery) |*discovery| {
        if (!partition.deinitialize(discovery)) return false;
        claims.Discovery = null;
    }
    return true;
}

pub fn finish(claims: *types.Claims) bool {
    if (sealed(claims)) return false;
    var paging_released = false;
    for (0..constants.ABORT_CLEANUP_ATTEMPTS) |attempt| {
        var released = true;
        if (claims.Handoff) |*state| {
            if (!handoff.deinitialize(state)) released = false;
        }
        if (!efi.pages.release(claims.Paging.BootServices, &claims.Image.Backing)) released = false;
        if (attempt == 0) paging_released = claims.Paging.deinitializeWithAttempts(constants.ABORT_CLEANUP_ATTEMPTS);
        if (!releaseReader(claims)) released = false;
        if (!releaseDiscovery(claims)) released = false;
        if (!releaseSource(claims)) released = false;
        if (released) return paging_released and !claims.Image.Untrusted;
    }
    return false;
}

fn sealed(claims: *const types.Claims) bool {
    return if (claims.Handoff) |state| state.ExitAttempted or state.Exited else false;
}
