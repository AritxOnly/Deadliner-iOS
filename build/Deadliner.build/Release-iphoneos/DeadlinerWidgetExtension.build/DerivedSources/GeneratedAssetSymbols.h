#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "create.tasks" asset catalog image resource.
static NSString * const ACImageNameCreateTasks AC_SWIFT_PRIVATE = @"create.tasks";

/// The "has.near.tasks" asset catalog image resource.
static NSString * const ACImageNameHasNearTasks AC_SWIFT_PRIVATE = @"has.near.tasks";

/// The "has.tasks" asset catalog image resource.
static NSString * const ACImageNameHasTasks AC_SWIFT_PRIVATE = @"has.tasks";

/// The "lifi.logo.v1" asset catalog image resource.
static NSString * const ACImageNameLifiLogoV1 AC_SWIFT_PRIVATE = @"lifi.logo.v1";

/// The "no.more.tasks" asset catalog image resource.
static NSString * const ACImageNameNoMoreTasks AC_SWIFT_PRIVATE = @"no.more.tasks";

#undef AC_SWIFT_PRIVATE
