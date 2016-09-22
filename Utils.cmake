#
# This file contains general CMake utilities
#

include(CMakeParseArguments)

#
# Discover GCC version
#
if(CMAKE_COMPILER_IS_GNUCXX)
  execute_process(COMMAND ${CMAKE_C_COMPILER} -dumpversion
      OUTPUT_VARIABLE GCC_VERSION)
  add_definitions(-DCMAKE_COMPILER_GCC)
elseif(MSVC)
  add_definitions(-DCMAKE_COMPILER_MSVC)
endif()

#
# Set platform-specific definitions
#
if(WIN32)
  add_definitions(-DCMAKE_PLATFORM_WINDOWS)
elseif(UNIX)
  add_definitions(-DCMAKE_PLATFORM_UNIX)
endif()

#
# === source_groups
#
#   Scans directory structure and creates source_groups for Visual Studio projects
#     - GroupName: base group name, typically "Source Files" or "Header Files" or "Resources"
#     - Directory: directory where files are located
#     - FilePattern: file search patterns, like "*.cpp" or "*.hpp"
#
function(source_groups GroupName Directory)
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
endfunction(source_groups)

#
# === target_setup_pch
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
function(target_setup_pch TARGET SOURCES_VAR PCH_HEADER PCH_SOURCE PCH_HEADER_PATH)
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
endfunction(target_setup_pch)

#
# === setup_pch
#
#   Setup precompiled headers for current target.
#   See target_setup_pch for explanations.
#
function(setup_pch SOURCES_VAR PCH_HEADER PCH_SOURCE PCH_HEADER_PATH)
  target_setup_pch(${PROJECT_NAME} ${SOURCES_VAR} ${PCH_HEADER} ${PCH_SOURCE} ${PCH_HEADER_PATH})
endfunction()

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
