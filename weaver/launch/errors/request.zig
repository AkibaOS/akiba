//! Weaver Provisioning And Layout Errors

const launch = @import("shared").launch;
const weaver = @import("weaver");

pub const RequestError = weaver.image.errors.layout.LayoutError || weaver.library.errors.library.LibraryError ||
    weaver.link.errors.link.LinkError || launch.errors.startup.StartupError || error{
    InvalidChild,
    InvalidStack,
    InvalidTicket,
    ProvisionRefused,
    RollbackRefused,
};
