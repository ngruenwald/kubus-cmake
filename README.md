# kubus-cmake
Retrieve packages from Kubus


## Setup
* Include the __kubus.cmake__ module.
* Enable Kubus by setting the __KUBUS__ option to ON
* Set the __KUBUS_SERVER__ variable
* _Optional_: Set your __KUBUS_CACHE_PATH__
* _Optional_: Set your required platfrom via __KUBUS_PLATFORM__


## Use
```
kubus_find_package(<PackageName> [version] 
                   [FORCE] [EXACT] [QUIET] [REQUIRED])
```

The ```FORCE``` option will ignore the cache and always download the package from the server.
The ```EXACT``` option requests that the version be matched exactly.
The ```QUIET``` option disables informal messages.
The ```REQUIRED``` optino stops processing with an error message if the package cannot be found.

The __kubus_find_package__ function will internally call __find_package__ and forward its arguments.
