#  PhysX_FOUND - system has PhysX
#  PhysX_INCLUDE_DIRS - the PhysX include directories
#  PhysX_LIBRARIES - link these to use PhysX
#  PhysX_SHARED_LIBRARIES_DEBUG - the shared libraries that need to be bundled with executables
#  PhysX_SHARED_LIBRARIES_RELEASE - the shared libraries that need to be bundled with executables

include(LibFindMacros)

set(PACKAGE_DIR ${3RDPARTY}/PhysX)

find_path(PhysX_INCLUDE_DIR PxPhysics.h
  PATHS ${PACKAGE_DIR}
  PATH_SUFFIXES Include inc include
  )

set(names
  PhysX3
  PhysX3Common
  PhysX3Cooking
  PhysX3Extensions
  PhysX3Vehicle
  PhysXProfileSDK
  PhysXVisualDebuggerSDK
  PvdRuntime
  PxTask
  SceneQuery
  LowLevel
  LowLevelCloth
  SimulationController
  )

set(libs)

if(WIN32)
  set(PHYSX_VS_PLATFORM_NAME "win32")

  if(CMAKE_VS_PLATFORM_NAME STREQUAL "x64")
    set(PHYSX_VS_PLATFORM_NAME "win64")
  endif()
endif()

foreach(name ${names})

  # Debug static libraries
  #
  find_library(PhysX_${name}_LIBRARY_DEBUG
    NAMES ${name}DEBUG ${name}DEBUG_x86 ${name}DEBUG_x64
    HINTS ${PACKAGE_DIR}/Lib
    PATH_SUFFIXES linux64 linux ${PHYSX_VS_PLATFORM_NAME}
    )

  # Release static libraries
  #
  find_library(PhysX_${name}_LIBRARY_RELEASE
    NAMES ${name} ${name}_x86 ${name}_x64
    HINTS ${PACKAGE_DIR}/Lib
    PATH_SUFFIXES linux64 linux ${PHYSX_VS_PLATFORM_NAME}
    )

  # Debug shared libraries
  #
  if(WIN32)
    find_file(PhysX_${name}_SHARED_LIBRARY_DEBUG
      NAMES ${name}DEBUG_x86.dll ${name}DEBUG_x64.dll
      HINTS ${PACKAGE_DIR}/Bin
      PATH_SUFFIXES ${PHYSX_VS_PLATFORM_NAME}
      )
  else()
    find_file(PhysX_${name}_SHARED_LIBRARY_DEBUG
      NAMES lib${name}DEBUG_x86.so lib${name}DEBUG_x64.so
      HINTS ${PACKAGE_DIR}/Bin
      PATH_SUFFIXES linux linux64
      )
  endif()

  # Release shared libraries
  #
  if(WIN32)
    find_file(PhysX_${name}_SHARED_LIBRARY_RELEASE
      NAMES ${name}_x86.dll ${name}_x64.dll
      HINTS ${PACKAGE_DIR}/Bin
      PATH_SUFFIXES ${PHYSX_VS_PLATFORM_NAME}
      )
  else()
    find_file(PhysX_${name}_SHARED_LIBRARY_RELEASE
      NAMES lib${name}_x86.so lib${name}_x64.so
      HINTS ${PACKAGE_DIR}/Bin
      PATH_SUFFIXES linux linux64
      )
  endif()

  list(APPEND libs PhysX_${name}_LIBRARY_DEBUG PhysX_${name}_LIBRARY_RELEASE)
  if(NOT ${PhysX_${name}_SHARED_LIBRARY_DEBUG} STREQUAL PhysX_${name}_SHARED_LIBRARY_DEBUG-NOTFOUND)
    list(APPEND PhysX_SHARED_LIBRARIES_DEBUG ${PhysX_${name}_SHARED_LIBRARY_DEBUG})
  endif()
  if(NOT ${PhysX_${name}_SHARED_LIBRARY_RELEASE} STREQUAL PhysX_${name}_SHARED_LIBRARY_RELEASE-NOTFOUND)
    list(APPEND PhysX_SHARED_LIBRARIES_RELEASE ${PhysX_${name}_SHARED_LIBRARY_RELEASE})
  endif()

endforeach()

if(WIN32)
  find_file(PhysX_nvTools_SHARED_LIBRARY
    NAMES nvToolsExt32_1.dll nvToolsExt64_1.dll
    HINTS ${PACKAGE_DIR}/Bin
    PATH_SUFFIXES ${PHYSX_VS_PLATFORM_NAME}
    )
  if(NOT ${PhysX_nvTools_SHARED_LIBRARY} STREQUAL PhysX_nvTools_SHARED_LIBRARY-NOTFOUND)
    list(APPEND PhysX_SHARED_LIBRARIES_DEBUG ${PhysX_nvTools_SHARED_LIBRARY})
    list(APPEND PhysX_SHARED_LIBRARIES_RELEASE ${PhysX_nvTools_SHARED_LIBRARY})
  endif()
endif()

# Set the include dir variables and the libraries and let libfind_process do the rest.
# NOTE: Singular variables for this library, plural for libraries this this lib depends on.
set(PhysX_PROCESS_INCLUDES PhysX_INCLUDE_DIR)
set(PhysX_PROCESS_LIBS ${libs})
libfind_process(PhysX)

set(PhysX_LIBRARIES)

if(CMAKE_COMPILER_IS_GNUCXX)
  list(APPEND PhysX_LIBRARIES -Wl,--start-group)
endif()

foreach(name ${names})
  list(APPEND PhysX_LIBRARIES
    optimized ${PhysX_${name}_LIBRARY_RELEASE}
    debug ${PhysX_${name}_LIBRARY_DEBUG}
    )
endforeach()

if(CMAKE_COMPILER_IS_GNUCXX)
  list(APPEND PhysX_LIBRARIES -ldl -Wl,--end-group)
endif()
