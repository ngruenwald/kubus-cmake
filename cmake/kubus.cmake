# kubus.cmake

option(KUBUS "Retrieve packages from Kubus server" OFF)

if(KUBUS)
  if(NOT DEFINED KUBUS_SERVER)
    if(DEFINED $ENV{KUBUS_SERVER})
      set(KUBUS_SERVER $ENV{KUBUS_SERVER})
    else()
      message(FATAL "KUBUS_SERVER not set")
    endif()
  endif()

  set(KUBUS_BASE_URL "${KUBUS_SERVER}/api/v1")

  if(NOT DEFINED KUBUS_CACHE_PATH)
    if(WIN32)
      set(KUBUS_CACHE_PATH "$ENV{LOCALAPPDATA}\\kubus\\cache")
    else()
      set(KUBUS_CACHE_PATH "$ENV{HOME}/.kubus/cache")
    endif()
  endif()

  if(WIN32)
    set(KUBUS_SEARCH_PATH "${KUBUS_CACHE_PATH}\\cmake")
    set(KUBUS_REL_SEARCH_PATH "cmake")
  else()
    set(KUBUS_SEARCH_PATH "${KUBUS_CACHE_PATH}/usr/local")
    set(KUBUS_REL_SEARCH_PATH "usr/local")
  endif()

  execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory "${KUBUS_CACHE_PATH}")
endif()

#
# Standard kubus functions
#

# find package
# param[in] name name of the package
# options: EXACT QUIET REQUIRED FORCE
function(kubus_find_package name)
  if(DEFINED ARGV1) # might not work as expected!
    set(version ${ARGV1})
  else()
    set(version "")
  endif()
  set(options FORCE EXACT QUIET REQUIRED)
  cmake_parse_arguments(KU "${options}" "${oneValueArgs}" "" ${ARGN})

  if(KUBUS)
    kubus_download_package("${name}" "${version}" ${KU_EXACT} ${KU_QUIET} ${KU_FORCE})
    if(NOT ${name}_KUBUS_FOUND)
      if(${KU_REQUIRED})
        message(FATAL_ERROR "Kubus package ${name} not found")
      else()
        message(STATUS "Kubus package ${name} not found")
      endif()
    else()
      find_package(
        ${ARGV}
        PATHS
          "${KUBUS_SEARCH_PATH}"
          "${KUBUS_CACHE_PATH}/${name}-${version}/${KUBUS_REL_SEARCH_PATH}"
        NO_DEFAULT_PATH
        NO_PACKAGE_ROOT_PATH
        NO_CMAKE_PATH
        NO_CMAKE_ENVIRONMENT_PATH
        NO_SYSTEM_ENVIRONMENT_PATH
        NO_CMAKE_PACKAGE_REGISTRY
        NO_CMAKE_SYSTEM_PATH
        NO_CMAKE_SYSTEM_PACKAGE_REGISTRY
      )
    endif()
  else()
    if(NOT ${quiet})
      message(STATUS "Kubus disabled")
    endif()
    find_package(${ARGV})
  endif()
endfunction(kubus_find_package)

# download kubus package
# param[in]   name    name of the package
# param[in]   version version of the package
# param[in]   exact   download exact version
# param[in]   quiet   silent download
# param[in]   force   force download even if the package already exists
function(kubus_download_package name version exact quiet force)
  if(NOT ${quiet})
    message("⛝ Kubus download ${name} ${version}")
  endif()
  if(NOT ${force})
    _kubus_check_cache(found artifact "${name}" "${version}" "${exact}")
  else()
    set(found FALSE)
  endif()
  if(NOT ${found})
    if(NOT ${quiet})
      if(${force})
        message("⛝ Kubus force download")
      else()
        message("⛝ Kubus artifact not in cache")
      endif()
    endif()
    _kubus_query_artifact(found url artifact "${name}" "${version}" "${exact}" "${quiet}")
    if(${found})
      if(NOT ${quiet})
        message("⛝ Kubus artifact found")
      endif()
      _kubus_download_to_cache(success ${url} ${artifact} ${quiet})
      if(${success})
        set(${name}_KUBUS_FOUND TRUE PARENT_SCOPE)
      endif()
    else()
      if(NOT ${quiet})
        message("⛝ Kubus artifact not found")
      endif()
    endif()
  else()
    if(NOT ${quiet})
      message("⛝ Kubus artifact in cache")
    endif()
    set(${name}_KUBUS_FOUND TRUE PARENT_SCOPE)
  endif()
endfunction(kubus_download_package)

#
# Internal functions
#

# check if artitfact exists in cache
# param[out]  found     TRUE/FALSE
# param[in]   artifact  name of the artifact
# param[in]   version   version of the artifact
# param[in]   exact     search for exact version
function(_kubus_check_cache found artifact name version exact)
  if(WIN32)
    set(folder "${KUBUS_CACHE_PATH}\\${name}-${version}")
    set(checksum "${folder}\\CHECKSUM")
  else()
    set(folder "${KUBUS_CACHE_PATH}/${name}-${version}")
    set(checksum "${folder}/CHECKSUM")
  endif()
  #if(EXISTS ${folder})
  if(EXISTS ${checksum})
    set(${found} TRUE PARENT_SCOPE)
  else()
    set(${found} FALSE PARENT_SCOPE)
  endif()
endfunction(_kubus_check_cache)

# download kubus artifact to cache
# param[out]  success   TRUE/FALSE
# param[in]   url       Kubus artifact URL
# param[in]   artifact  full name of the artifact file
# param[in]   quiet     silent download
function(_kubus_download_to_cache success url artifact quiet)
  if(NOT ${quiet})
    message("⛝ Kubus download to cache: url=${url} artifact=${artifact}")
    message("⛝ Kubus cache path: ${KUBUS_CACHE_PATH}")
  endif()

  # execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory "${KUBUS_CACHE_PATH}")
  file(DOWNLOAD "${url}" "${KUBUS_CACHE_PATH}/${artifact}")

  if(WIN32)
    set(working_directory "${KUBUS_CACHE_PATH}\\${name}-${version}")
  else()
    # set(working_directory "${KUBUS_CACHE_PATH}")
    set(working_directory "${KUBUS_CACHE_PATH}/${name}-${version}")
  endif()

  execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory "${working_directory}")
  execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf "${KUBUS_CACHE_PATH}/${artifact}" WORKING_DIRECTORY "${working_directory}")
  file(SHA256 "${KUBUS_CACHE_PATH}/${artifact}" artifact_hash)
  file(WRITE "${working_directory}/CHECKSUM" "${artifact_hash}")
  file(REMOVE "${KUBUS_CACHE_PATH}/${artifact}")
  set(${success} TRUE PARENT_SCOPE)
endfunction(_kubus_download_to_cache)

# query kubus artifact
# param[out]  found     TRUE/FALSE
# param[out]  url       Kubus URL of the artifact
# param[out]  artifact  full name of the artifact
# param[in]   name      name of the artifact
# param[in]   version   version of the artifact
# param[in]   exact     search for exact version
# param[in]   quiet     silent lookup
function(_kubus_query_artifact found url artifact name version exact quiet)
  if(DEFINED KUBUS_PLATFORM)
    set(platform ${KUBUS_PLATFORM})
  else()
    _kubus_get_platform(platform)
  endif()

  if(NOT ${quiet})
    message("⛝ Kubus platform: ${platform}")
  endif()

  set(json_file "${KUBUS_CACHE_PATH}/${name}-${version}.json")
  file(
    DOWNLOAD
    "${KUBUS_BASE_URL}/search?component=${name}&version=${version}&platform=${platform}&return=artifact"
    "${json_file}"
    STATUS status
  )
  list(GET status 0 result)

  # test
  if(FALSE)
    if(NOT ${result} EQUAL 0)
      message(STATUS "status: ${status} (result=${result})")
      execute_process(COMMAND ${CMAKE_COMMAND} -E copy "${KUBUS_CACHE_PATH}/test.json" "${json_file}")
      set(result 0)
    endif()
  endif()

  if(${result} EQUAL 0)
    set(artifact_id_regex "\"id\"[\\r\\n\\t ]*:[\\r\\n\\t ]*(.+)[\\r\\n\\t ]*,")
    file(STRINGS "${json_file}" artifact_id REGEX ${artifact_id_regex})
    list(GET artifact_id 0 artifact_id)
    string(REGEX REPLACE ${artifact_id_regex} "\\1" artifact_id "${artifact_id}")
    string(STRIP "${artifact_id}" artifact_id)

    set(artifact_name_regex "\"filename\"[\\r\\n\\t ]*:[\\r\\n\\t ]*\"(.+)\"[\\r\\n\\t ]*,")
    file(STRINGS "${json_file}" artifact_name REGEX ${artifact_name_regex})
    list(GET artifact_name 0 artifact_name)
    string(REGEX REPLACE ${artifact_name_regex} "\\1" artifact_name "${artifact_name}")
    string(STRIP "${artifact_name}" artifact_name)

    set(${found} TRUE PARENT_SCOPE)
    set(${url} "${KUBUS_BASE_URL}/artifacts/${artifact_id}/file" PARENT_SCOPE)
    set(${artifact} ${artifact_name} PARENT_SCOPE)
  endif()

  file(REMOVE "${json_file}")
endfunction(_kubus_query_artifact)

# determine platform name
# @param[out] platform
function(_kubus_get_platform platform)
  set(platform "")

  if(WIN32)
    set(platform "win")
  else()
    if(EXISTS "/etc/redhat-release")
      _kubus_read_el_version("/etc/redhat-release" platform)
    elseif(EXISTS "/etc/SuSe-release")
      _kubus_read_suse_version("/etc/SuSe-release" platform)
    elseif(EXISTS "/etc/arch-release")
      set(platform "arch")
    else()
      # extend me
    endif()
  endif()

  set(platform "${platform}" PARENT_SCOPE)

endfunction(_kubus_get_platform)

# reads the Enterprise Linux version from the specified file
# param[in]   release_file      the path of the source file
# param[out]  release_version   the version information
function(_kubus_read_el_version release_version)
  file(READ "${release_file}" contents)
  string(REGEX REPLACE ".* release (.*)\\.(.*)\\..*" "\\1;\\2" parts "${contents}")
  list(LENGTH parts length)
  if(${length} EQUAL 2)
    list(GET parts 0 major)
    list(GET parts 1 minor)
    # set(${release_version} "el${major}_${minor}" PARENT_SCOPE)
    set(${release_version} "el${major}" PARENT_SCOPE)
  endif()
endfunction(_kubus_read_el_version)

# reads the SuSE Linux version from the specified file.
# param[in]   release_file      the path of the source file
# param[out]  release_version   the version information
function(_kubus_read_sles_version release_version)
  file(READ "${release_file}" contents)
  string(REGEX REPLACE ";" "\\\\;" contents "${contents}")
  string(REGEX REPLACE "\n" ";" contents "${contents}")

  set(major "x")
  set(minor "x")

  foreach(line IN LISTS contents)
    if(NOT "${line}" STREQUAL "")
      string(REGEX REPLACE "(.*) = (.*)" "\\1;\\2" key_value ${line})
      list(LENGTH key_value count)
      if(${count} EQUAL 2)
        list(GET key_value 0 key)
        list(GET key_value 1 value)
        if("${key}" STREQUAL "VERSION")
          set(major "${value}")
        endif()
        if("${key}" STREQUAL "PATCHLEVEL")
          set(minor "${value}")
        endif()
      endif()
    endif()
  endforeach()

  if(NOT ${major} STREQUAL "x" AND NOT ${minor} STREQUAL "x")
    # set(${release_version} "sles${major}_${minor}" PARENT_SCOPE)
    set(${release_version} "sles${major}" PARENT_SCOPE)
  endif()
endfunction(_kubus_read_sles_version)
