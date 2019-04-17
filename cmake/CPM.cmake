cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

if(CPM_DIRECTORY)
  if(NOT ${CPM_DIRECTORY} MATCHES ${CMAKE_CURRENT_LIST_DIR})
    return()
  endif()
endif()

set(CPM_DIRECTORY ${CMAKE_CURRENT_LIST_DIR} CACHE INTERNAL "")
set(CPM_PACKAGES "" CACHE INTERNAL "")

option(CPM_LOCAL_PACKAGES_ONLY "Use only locally installed packages" OFF)
option(CPM_REMOTE_PACKAGES_ONLY "Always download packages" OFF)

include(FetchContent)
include(CMakeParseArguments)

if(NOT CPM_INDENT)
  set(CPM_INDENT "CPM:")
endif()

function(CPM_REGISTER_PACKAGE PACKAGE VERSION)
  LIST(APPEND CPM_PACKAGES ${CPM_ARGS_NAME})
  set(CPM_PACKAGES ${CPM_PACKAGES} CACHE INTERNAL "")
  CPM_SET_PACKAGE_VERSION(${PACKAGE} ${VERSION})
endfunction()

function(CPM_SET_PACKAGE_VERSION PACKAGE VERSION)
  set("CPM_PACKAGE_${PACKAGE}_VERSION" ${VERSION} CACHE INTERNAL "")
endfunction()

function(CPM_GET_PACKAGE_VERSION PACKAGE)
  set(CPM_PACKAGE_VERSION "${CPM_PACKAGE_${PACKAGE}_VERSION}" PARENT_SCOPE)
endfunction()

function(CPM_PARSE_OPTION OPTION)
  string(REGEX MATCH "^[^ ]+" OPTION_KEY ${OPTION})
  string(LENGTH ${OPTION_KEY} OPTION_KEY_LENGTH)
  math(EXPR OPTION_KEY_LENGTH "${OPTION_KEY_LENGTH}+1")
  string(SUBSTRING ${OPTION} "${OPTION_KEY_LENGTH}" "-1" OPTION_VALUE)
  set(OPTION_KEY "${OPTION_KEY}" PARENT_SCOPE)
  set(OPTION_VALUE "${OPTION_VALUE}" PARENT_SCOPE)
endfunction()

function(CPMAddPackage)
    
  set(oneValueArgs
    NAME
    VERSION
    GIT_TAG
  )

  set(multiValueArgs
    OPTIONS
  )

  cmake_parse_arguments(CPM_ARGS "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if (CPM_ARGS_VERSION AND NOT CPM_ARGS_OPTIONS AND NOT ${CPM_REMOTE_PACKAGES_ONLY})
    find_package(${CPM_ARGS_NAME} ${CPM_ARGS_VERSION} QUIET)

    if(${CPM_PACKAGE_FOUND})
      message(STATUS "CPM: adding local package ${CPM_ARGS_NAME}@${CPM_ARGS_VERSION}")
      set_target_properties(${CPM_ARGS_NAME} 
        PROPERTIES
          IMPORTED_GLOBAL True
      )
      return()
    endif()
  endif()

  if (NOT CPM_ARGS_VERSION)
    set(CPM_ARGS_VERSION 0)
  endif()

  if (NOT CPM_ARGS_GIT_TAG)
    set(CPM_ARGS_GIT_TAG v${CPM_ARGS_VERSION})
  endif()

  if (${CPM_ARGS_NAME} IN_LIST CPM_PACKAGES)
    CPM_GET_PACKAGE_VERSION(${CPM_ARGS_NAME})
    if(${CPM_PACKAGE_VERSION} VERSION_LESS ${CPM_ARGS_VERSION})
      message(WARNING "${CPM_INDENT} newer package ${CPM_ARGS_NAME} requested (${CPM_ARGS_VERSION}, currently using ${CPM_PACKAGE_VERSION})")
    endif()
    if (CPM_ARGS_OPTIONS)
      foreach(OPTION ${CPM_ARGS_OPTIONS})
        CPM_PARSE_OPTION(${OPTION})
        if(NOT "${${OPTION_KEY}}" STREQUAL ${OPTION_VALUE})
          message(WARNING "${CPM_INDENT} ignoring package option for ${CPM_ARGS_NAME}: ${OPTION_KEY} = ${OPTION_VALUE} (${${OPTION_KEY}})")
        else()
          message(STATUS "${CPM_INDENT} NOT ignoring package option for ${CPM_ARGS_NAME}: ${OPTION_KEY} = ${OPTION_VALUE} (${${OPTION_KEY}})")
        endif()
      endforeach()
    endif()
    CPM_FETCH_PACKAGE(${CPM_ARGS_NAME})
    return()
  endif()

  CPM_REGISTER_PACKAGE(${CPM_ARGS_NAME} ${CPM_ARGS_VERSION})

  if (CPM_ARGS_OPTIONS)
    foreach(OPTION ${CPM_ARGS_OPTIONS})
      CPM_PARSE_OPTION(${OPTION})
      set(${OPTION_KEY} ${OPTION_VALUE} CACHE INTERNAL "")
    endforeach()
  endif()

  CPM_DECLARE_PACKAGE(${CPM_ARGS_NAME} ${CPM_ARGS_VERSION} ${CPM_ARGS_GIT_TAG} "${CPM_ARGS_UNPARSED_ARGUMENTS}")
  CPM_FETCH_PACKAGE(${CPM_ARGS_NAME})
endfunction()

function (CPM_DECLARE_PACKAGE PACKAGE VERSION GIT_TAG)
  message(STATUS "${CPM_INDENT} adding package ${PACKAGE}@${VERSION} (${GIT_TAG})")

  FetchContent_Declare(
    ${PACKAGE}
    GIT_TAG ${GIT_TAG}
    ${ARGN}
  )
endfunction()

function (CPM_FETCH_PACKAGE PACKAGE)  
  set(CPM_OLD_INDENT "${CPM_INDENT}")
  set(CPM_INDENT "${CPM_INDENT} ${PACKAGE}:")
  FetchContent_MakeAvailable(${PACKAGE})
  set(CPM_INDENT "${CPM_OLD_INDENT}")
endfunction()