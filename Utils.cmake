include(CMakeParseArguments)

#
# Discover GCC version
#
if(CMAKE_COMPILER_IS_GNUCXX)
  execute_process(COMMAND ${CMAKE_C_COMPILER} -dumpversion
      OUTPUT_VARIABLE GCC_VERSION)
endif()

#
# === wos_source_groups
#
#   Scans directory structure and creates source_groups for Visual Studio projects
#     - GroupName: base group name, typically "Source Files" or "Header Files" or "Resources"
#     - Directory: directory where files are located
#     - FilePattern: file search patterns, like "*.cpp" or "*.hpp"
#
function(wos_source_groups GroupName Directory)
  # Glob all sources file inside directory ${Directory}
  file(GLOB_RECURSE FILES ${ARGN})

  foreach(f ${FILES})
    file(RELATIVE_PATH SRCGR ${PROJECT_SOURCE_DIR}/${Directory} ${f})
    set(SRCGR "${GroupName}/${SRCGR}")

    # Extract the folder, ie remove the filename part
    string(REGEX REPLACE "(.*)(/[^/]*)$" "\\1" SRCGR ${SRCGR})

    # Source_group expects \\ (double antislash), not / (slash)
    string(REPLACE / \\ SRCGR ${SRCGR})
    source_group("${SRCGR}" FILES ${f})
  endforeach()
endfunction(wos_source_groups)

#
# === wos_sources
#
#   Gather sources for current platform, using following conventions:
#     - Files which names end with "PC" or "Windows"
#       are only for Windows platform.
#     - Files which path contains folder "Win" or "Windows" are only for Windows.
#     - Files which names end with "Linux" are only for Linux.
#     - Files which path contains folder "linux" are only for Linux.
#
#   Some examples:
#     Sources/Linux/Test.cpp    - Linux only
#     Base/TestPC.cpp           - Windows only
#     Base/Test/TestLinux.c     - Linux only
#     Base/Win/Test.cpp         - Windows only
#
#   Arguments:
#     VAR - the variable to put the list of files into
#
function(wos_sources VAR)

  file(GLOB_RECURSE FILES RELATIVE ${PROJECT_SOURCE_DIR} *.hpp *.cpp *.h *.c *.inl)

  #
  # === Linux sources
  #
  if(UNIX)
    foreach(FILE ${FILES})
      # Remove windows specific files
      if(${FILE} MATCHES ".*Windows\\.[ch](pp)?" OR
          ${FILE} MATCHES ".*PC\\.[ch](pp)?" OR
          ${FILE} MATCHES "^(.*/)?Win/.*$" OR
          ${FILE} MATCHES "^(.*/)?Windows/.*$" OR
          ${FILE} MATCHES "^(.*/)?windows/.*$")
        list(REMOVE_ITEM FILES ${FILE})
      endif()
    endforeach()
  endif()

  #
  # === Windows sources
  #
  if(WIN32)
    foreach(FILE ${FILES})
      # Remove linux specific files
      if(${FILE} MATCHES ".*Linux\\.[ch](pp)?" OR
          ${FILE} MATCHES "^(.*/)?Linux/.*$" OR
          ${FILE} MATCHES "^(.*/)?linux/.*$")
        list(REMOVE_ITEM FILES ${FILE})
      endif()
    endforeach()
  endif()

  # Remove files from Test/ folder
  foreach(FILE ${FILES})
    # Remove linux specific files
    if(${FILE} MATCHES "Test/.*")
      list(REMOVE_ITEM FILES ${FILE})
    endif()
  endforeach()

  # Unity sources are not used in cmake builds
  list(REMOVE_ITEM FILES Unity.cpp)
  list(REMOVE_ITEM FILES Sources/Unity.cpp)
  list(REMOVE_ITEM FILES Source/Unity.cpp)

  set(${VAR} ${FILES} PARENT_SCOPE)

endfunction(wos_sources)

#
# === wos_setup_library
#
#   Typical setup for library projects that follow conventions.
#
#   Arguments:
#     DEPS <dependecies>  - list of dependencies
#     SHARED              - whether to build as shared lib (linkage by default is static)
#     EXCLUDES <excludes> - list of source files to exclude from build
#
#   Usage:
#     wos_setup_library([DEPS <dependencies> ...] [EXCLUDES <excludes> ...] [SHARED])
#
function(wos_setup_library)
  set(options SHARED)
  set(oneValueArgs PCH_HEADER PCH_SOURCE)
  set(multiValueArgs DEPS EXCLUDES)
  cmake_parse_arguments(wos_setup_library "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT wos_setup_library_PCH_HEADER)
    # Try to discover precompiled header if not set
    if(EXISTS ${CMAKE_SOURCE_DIR}/Common/${PROJECT_NAME}/${PROJECT_NAME}PCH.hpp)
      set(wos_setup_library_PCH_HEADER ${PROJECT_NAME}/${PROJECT_NAME}PCH.hpp)
      set(wos_setup_library_PCH_HEADER_PATH ${CMAKE_SOURCE_DIR}/Common/${PROJECT_NAME}/${PROJECT_NAME}PCH.hpp)
    elseif(EXISTS ${CMAKE_SOURCE_DIR}/Shared/${PROJECT_NAME}/${PROJECT_NAME}PCH.hpp)
      set(wos_setup_library_PCH_HEADER ${PROJECT_NAME}/${PROJECT_NAME}PCH.hpp)
      set(wos_setup_library_PCH_HEADER_PATH ${CMAKE_SOURCE_DIR}/Shared/${PROJECT_NAME}/${PROJECT_NAME}PCH.hpp)
    elseif(EXISTS ${PROJECT_SOURCE_DIR}/Source/${PROJECT_NAME}PCH.hpp)
      set(wos_setup_library_PCH_HEADER ${PROJECT_NAME}PCH.hpp)
      set(wos_setup_library_PCH_HEADER_PATH ${PROJECT_SOURCE_DIR}/Source/${PROJECT_NAME}PCH.hpp)
    elseif(EXISTS ${PROJECT_SOURCE_DIR}/Include/${PROJECT_NAME}PCH.hpp)
      set(wos_setup_library_PCH_HEADER ${PROJECT_NAME}PCH.hpp)
      set(wos_setup_library_PCH_HEADER_PATH ${PROJECT_SOURCE_DIR}/Include/${PROJECT_NAME}PCH.hpp)
    elseif(EXISTS ${PROJECT_SOURCE_DIR}/stdafx.h)
      set(wos_setup_library_PCH_HEADER stdafx.h)
      set(wos_setup_library_PCH_HEADER_PATH ${PROJECT_SOURCE_DIR}/stdafx.h)
    elseif(EXISTS ${PROJECT_SOURCE_DIR}/Source/stdafx.h)
      set(wos_setup_library_PCH_HEADER stdafx.h)
      set(wos_setup_library_PCH_HEADER_PATH ${PROJECT_SOURCE_DIR}/Source/stdafx.h)
    endif()
  else()
    # Trying to find a header file location
    if(EXISTS ${CMAKE_SOURCE_DIR}/Common/${wos_setup_library_PCH_HEADER})
      set(wos_setup_library_PCH_HEADER_PATH ${CMAKE_SOURCE_DIR}/Common/${wos_setup_library_PCH_HEADER})
    elseif(EXISTS ${CMAKE_SOURCE_DIR}/Shared/${wos_setup_library_PCH_HEADER})
      set(wos_setup_library_PCH_HEADER_PATH ${CMAKE_SOURCE_DIR}/Shared/${wos_setup_library_PCH_HEADER})
    elseif(EXISTS ${PROJECT_SOURCE_DIR}/${wos_setup_library_PCH_HEADER})
      set(wos_setup_library_PCH_HEADER_PATH ${PROJECT_SOURCE_DIR}/${wos_setup_library_PCH_HEADER})
    elseif(EXISTS ${PROJECT_SOURCE_DIR}/Source/${wos_setup_library_PCH_HEADER})
      set(wos_setup_library_PCH_HEADER_PATH ${PROJECT_SOURCE_DIR}/Source/${wos_setup_library_PCH_HEADER})
    elseif(EXISTS ${PROJECT_SOURCE_DIR}/Include/${wos_setup_library_PCH_HEADER})
      set(wos_setup_library_PCH_HEADER_PATH ${PROJECT_SOURCE_DIR}/Include/${wos_setup_library_PCH_HEADER})
    endif()
  endif()

  # Try to discover precompiled source if not set
  if(NOT wos_setup_library_PCH_SOURCE)
    if(EXISTS ${CMAKE_SOURCE_DIR}/Common/${PROJECT_NAME}/${PROJECT_NAME}PCH.cpp)
      set(wos_setup_library_PCH_SOURCE ${PROJECT_NAME}/${PROJECT_NAME}PCH.cpp)
    elseif(EXISTS ${CMAKE_SOURCE_DIR}/Shared/${PROJECT_NAME}/${PROJECT_NAME}PCH.cpp)
      set(wos_setup_library_PCH_SOURCE ${PROJECT_NAME}/${PROJECT_NAME}PCH.cpp)
    elseif(EXISTS ${PROJECT_SOURCE_DIR}/Source/${PROJECT_NAME}PCH.cpp)
      set(wos_setup_library_PCH_SOURCE Source/${PROJECT_NAME}PCH.cpp)
    elseif(EXISTS ${PROJECT_SOURCE_DIR}/stdafx.cpp)
      set(wos_setup_library_PCH_SOURCE stdafx.cpp)
    elseif(EXISTS ${PROJECT_SOURCE_DIR}/Source/stdafx.cpp)
      set(wos_setup_library_PCH_SOURCE Source/stdafx.cpp)
    endif()
  endif()

  if(EXISTS ${PROJECT_SOURCE_DIR}/Inc)
    include_directories(Inc)
  endif()
  if(EXISTS ${PROJECT_SOURCE_DIR}/Include)
    include_directories(Include)
  endif()
  if(EXISTS ${PROJECT_SOURCE_DIR}/Source)
    include_directories(Source)
  endif()

  include_directories(.)

  wos_sources(SOURCES)
  wos_headers(SOURCES)

  message(STATUS "Setting up library: ${PROJECT_NAME}")

  foreach(FILE ${wos_setup_library_EXCLUDES})
    message(STATUS "  Excluding: ${FILE}")
    list(REMOVE_ITEM SOURCES ${FILE})
  endforeach()

  wos_source_groups("Source Files" Source Source/*.c Source/*.cpp Source/*.h Source/*.hpp Source/*.inl)
  wos_source_groups("Source Files" . *.c *.cpp *.inl)
  wos_source_groups("Source Files" . Inc/*.h Inc/*.hpp)
  wos_source_groups("Resources" Resource Resource/*.h Resource/*.rc)

  if(wos_setup_library_SHARED)
    add_library(${PROJECT_NAME} SHARED ${SOURCES})

    if(WOS_DEFBUILD)
      if(EXISTS ${PROJECT_SOURCE_DIR}/wsp10/DefBuildIgnores.txt)
        file(COPY ${PROJECT_SOURCE_DIR}/wsp10/DefBuildIgnores.txt
          DESTINATION ${PROJECT_BINARY_DIR})
      endif()
      add_custom_command(TARGET ${PROJECT_NAME}
        PRE_LINK
        COMMAND ${WOS_DEFBUILD} ${PROJECT_NAME}.def
        WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
        )
      set_target_properties(${PROJECT_NAME} PROPERTIES LINK_FLAGS "${LINK_FLAGS} /DEF:${PROJECT_NAME}.def")
    endif()
  else()
    add_library(${PROJECT_NAME} STATIC ${SOURCES})
  endif()

  if(wos_setup_library_PCH_HEADER AND wos_setup_library_PCH_SOURCE)
    wos_setup_pch(SOURCES ${wos_setup_library_PCH_HEADER} ${wos_setup_library_PCH_SOURCE}
      ${wos_setup_library_PCH_HEADER_PATH})
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}" PARENT_SCOPE)
  endif()

  if(wos_setup_library_DEPS)
    message(STATUS "  Adding dependencies: ${wos_setup_library_DEPS}")
    set(WOS_DEPS_${PROJECT_NAME} "${wos_setup_library_DEPS}" CACHE STRING "${PROJECT_NAME} library deps")
  endif()

  target_link_libraries(${PROJECT_NAME} ${wos_setup_library_DEPS})
endfunction()

#
# === wos_target_setup_pch
#
#   Setup precompiled headers for supported environments.
#
#   Arguments:
#     TARGET          - target name
#     SOURCES_VAR     - the variable containing the list of source files
#     PCH_HEADER      - the header that needs to be precompiled, as it appears in #include statement
#     PCH_SOURCE      - the source for precompiled header (for MSVC only)
#     PCH_HEADER_PATH - full path to the header
#
function(wos_target_setup_pch TARGET SOURCES_VAR PCH_HEADER PCH_SOURCE PCH_HEADER_PATH)
  message(STATUS "  Setting up PCH: ${PCH_HEADER} ${PCH_SOURCE}")

  # MSVC precompiled headers
  if(MSVC)
    set(PCH_BINARY ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}.pch)

    list(REMOVE_ITEM ${SOURCES_VAR} ${PCH_SOURCE})

    foreach(FILE ${${SOURCES_VAR}})
      get_filename_component(EXT ${FILE} EXT)
      if(${EXT} MATCHES "^.*\\.cpp$")
        set_source_files_properties(${FILE}
          PROPERTIES COMPILE_FLAGS "/Yu\"${PCH_HEADER}\" /FI\"${PCH_HEADER}\"")
      endif()
    endforeach()
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /Yu\"${PCH_HEADER}\"" PARENT_SCOPE)

    set_source_files_properties(${PCH_SOURCE}
      PROPERTIES COMPILE_FLAGS "/Yc\"${PCH_HEADER}\"")
  endif()

  # GCC precompiled headers
  if(CMAKE_COMPILER_IS_GNUCXX AND PCH_HEADER_PATH AND PCH_HEADER_PATH)
    target_include_directories(${TARGET} BEFORE PRIVATE "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/pch/${TARGET}")
    set_target_properties(${TARGET} PROPERTIES COMPILE_FLAGS "-Winvalid-pch")

    # pch binary output path
    set(PCH_BINARY ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/pch/${TARGET}/${PCH_HEADER}.gch)

    # Create pch binary dir
    get_filename_component(PCH_DIR ${PCH_BINARY} DIRECTORY)
    file(MAKE_DIRECTORY ${PCH_DIR})

    # copy the header to intermediate directory
    file(COPY ${PCH_HEADER_PATH} DESTINATION ${PCH_DIR})

    # Gather compile flags for current directory ...
    set(_COMPILER_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}}")

    get_directory_property(_DIRECTORY_FLAGS INCLUDE_DIRECTORIES)
    foreach(item ${_DIRECTORY_FLAGS})
      list(APPEND _COMPILER_FLAGS "-I${item}")
    endforeach(item)

    get_directory_property(_DIRECTORY_FLAGS COMPILE_DEFINITIONS)
    foreach(item ${_DIRECTORY_FLAGS})
      list(APPEND _COMPILER_FLAGS "-D${item}")
    endforeach(item)

    separate_arguments(_COMPILER_FLAGS)

    # Custom target to build pch binary
    add_custom_command(
      OUTPUT ${PCH_BINARY}
      COMMAND ${CMAKE_CXX_COMPILER}
      ARGS ${_COMPILER_FLAGS} -x c++-header -c -o ${PCH_BINARY} ${PCH_HEADER_PATH}
      DEPENDS ${${SOURCES_VAR}})
    add_custom_target(${TARGET}_pch DEPENDS ${PCH_BINARY})
    add_dependencies(${TARGET} ${TARGET}_pch)
  endif()
endfunction(wos_target_setup_pch)

#
# === wos_setup_pch
#
#   Setup precompiled headers for current target.
#   See wos_target_setup_pch for explanations.
#
function(wos_setup_pch SOURCES_VAR PCH_HEADER PCH_SOURCE PCH_HEADER_PATH)
  wos_target_setup_pch(${PROJECT_NAME} ${SOURCES_VAR} ${PCH_HEADER} ${PCH_SOURCE} ${PCH_HEADER_PATH})
endfunction()

#
# === wos_headers
#
function(wos_headers VAR)
  file(GLOB_RECURSE FILES *.h *.hpp)
  list(APPEND ${VAR} ${FILES})
  set(${VAR} ${${VAR}} PARENT_SCOPE)
endfunction(wos_headers)

#
# === add_config_definitions
#
#   Add configuration-specific definitions.
#
#   Usage:
#     add_config_definitons(<config> -D<define> -D<define> ...)
#
function(add_config_definitions CONFIG)
  string(REGEX REPLACE ";" " " STR "${ARGN}")
  if(CMAKE_COMPILER_IS_GNUCXX)
    set(CMAKE_CXX_FLAGS_${CONFIG} "${CMAKE_CXX_FLAGS_${CONFIG}} ${STR}" PARENT_SCOPE)
  endif(CMAKE_COMPILER_IS_GNUCXX)
  if(MSVC)
    string(REGEX REPLACE "-D" "/D" MSVC_DEFINES "${STR}")
    set(CMAKE_CXX_FLAGS_${CONFIG} "${CMAKE_CXX_FLAGS_${CONFIG}} ${MSVC_DEFINES}" PARENT_SCOPE)
  endif(MSVC)
endfunction(add_config_definitions)

#
# === scan_subprojects
#
#   Look for CMakeLists.txt files in directory DIR recursively,
#   and add them as subprojects.
#
function(scan_subprojects DIR)
  file(GLOB_RECURSE COMMON_SUBPROJECTS RELATIVE ${CMAKE_SOURCE_DIR} ${DIR}/*/CMakeLists.txt)
  foreach(SUBPROJECT ${COMMON_SUBPROJECTS})
    get_filename_component(SUBPROJECT ${SUBPROJECT} DIRECTORY)
    add_subdirectory(${SUBPROJECT})
  endforeach()
endfunction()

#
# === target_copy_shared_libs
#
#   Schedules the copying of shared libraries to executable output path.
#   The libraries are copied on the post-build event.
#   For single-configuration builds debug-level libraries are used for DEBUG configuration,
#   release libraries for RELEASE, FINAL and FINALGAMEMASTER configurations.
#   For multi-configuration build (MSVC) debug libraries are used for "Debug" configuration
#   release libraries are used for "Release", "Final" and "FinalGameMaster" configurations.
#
#   Arguments:
#     TARGET            - build target
#     DEBUG_LIBS_VAR    - the name of the variable which contains a list of debug-level libraries
#     RELEASE_LIBS_VAR  - the name of the variable which contains a list of release-level libraries
#
function(target_copy_shared_libs TARGET DEBUG_LIBS_VAR RELEASE_LIBS_VAR)
  if(MSVC)
    list(LENGTH ${DEBUG_LIBS_VAR} DEBUG_LEN)
    list(LENGTH ${RELEASE_LIBS_VAR} RELEASE_LEN)
    if(NOT DEBUG_LEN EQUAL RELEASE_LEN)
      message(WARNING "Debug and release shared libs lists must be of equal length")
    else()
      # The output directory may not exist yet (for VS2010 at least)
      add_custom_command(TARGET ${TARGET} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>)

      set(DEBUG_INDEX 0)
      set(RELEASE_INDEX 0)
      while(DEBUG_INDEX LESS DEBUG_LEN)
        list(GET ${DEBUG_LIBS_VAR} ${DEBUG_INDEX} DEBUG_LIB)
        list(GET ${RELEASE_LIBS_VAR} ${RELEASE_INDEX} RELEASE_LIB)

        add_custom_command(TARGET ${TARGET} POST_BUILD
          COMMAND ${CMAKE_COMMAND} -E copy
          $<$<CONFIG:Debug>:${DEBUG_LIB}>
          $<$<CONFIG:Release>:${RELEASE_LIB}>
          $<$<CONFIG:Final>:${RELEASE_LIB}>
          $<$<CONFIG:FinalGameMaster>:${RELEASE_LIB}>
          ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>/
          )

        # check if .pdb exists and add
        string(REPLACE ".dll" ".pdb" DEBUG_LIB_PDB "${DEBUG_LIB}")
        string(REPLACE ".dll" ".pdb" RELEASE_LIB_PDB "${RELEASE_LIB}")
        if(EXISTS "${DEBUG_LIB_PDB}" AND EXISTS "${RELEASE_LIB_PDB}")
          add_custom_command(TARGET ${TARGET} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy
            $<$<CONFIG:Debug>:${DEBUG_LIB_PDB}>
            $<$<CONFIG:Release>:${RELEASE_LIB_PDB}>
            $<$<CONFIG:Final>:${RELEASE_LIB_PDB}>
            $<$<CONFIG:FinalGameMaster>:${RELEASE_LIB_PDB}>
            ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>/
            )
        endif()

        math(EXPR DEBUG_INDEX "${DEBUG_INDEX} + 1")
        math(EXPR RELEASE_INDEX "${RELEASE_INDEX} + 1")
      endwhile()
    endif()
  else()
    if (${CMAKE_BUILD_TYPE} STREQUAL "DEBUG")
      foreach(LIB ${${LIBS_DEBUG_VAR}})
        add_custom_command(TARGET ${TARGET} POST_BUILD
          COMMAND ${CMAKE_COMMAND} -E copy
          ${LIB} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
          )
      endforeach()
    else()
      foreach(LIB ${${LIBS_RELEASE_VAR}})
        add_custom_command(TARGET ${TARGET} POST_BUILD
          COMMAND ${CMAKE_COMMAND} -E copy
          ${LIB} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
          )
      endforeach()
    endif()
  endif()
endfunction()

#
# === copy_shared_libs
#
#   Call target_copy_shared_libs with PROJECT_NAME as target.
#   See the description for target_copy_shared_libs.
#
function(copy_shared_libs DEBUG_LIBS_VAR RELEASE_LIBS_VAR)
  target_copy_shared_libs(${PROJECT_NAME} ${DEBUG_LIBS_VAR} ${RELEASE_LIBS_VAR})
endfunction()
