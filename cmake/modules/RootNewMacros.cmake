#---------------------------------------------------------------------------------------------------
#  RootNewMacros.cmake
#---------------------------------------------------------------------------------------------------
cmake_policy(SET CMP0003 NEW) # See "cmake --help-policy CMP0003" for more details
cmake_policy(SET CMP0011 NEW) # See "cmake --help-policy CMP0011" for more details
cmake_policy(SET CMP0009 NEW) # See "cmake --help-policy CMP0009" for more details
if(CMAKE_VERSION VERSION_GREATER 2.8.12)
  cmake_policy(SET CMP0022 OLD) # See "cmake --help-policy CMP0022" for more details
endif()

set(lib lib)
set(bin bin)
if(WIN32)
  set(ssuffix .bat)
  set(scomment rem)
  set(libprefix lib)
  set(ld_library_path PATH)
  set(libsuffix .dll)
  set(runtimedir ${CMAKE_INSTALL_BINDIR})
elseif(APPLE)
  set(ld_library_path DYLD_LIBRARY_PATH)
  set(ssuffix .csh)
  set(scomment \#)
  set(libprefix lib)
  set(libsuffix .so)
  set(runtimedir ${CMAKE_INSTALL_LIBDIR})
else()
  set(ld_library_path LD_LIBRARY_PATH)
  set(ssuffix .csh)
  set(scomment \#)
  set(libprefix lib)
  set(libsuffix .so)
  set(runtimedir ${CMAKE_INSTALL_LIBDIR})
endif()

if(soversion)
  set(ROOT_LIBRARY_PROPERTIES ${ROOT_LIBRARY_PROPERTIES}
      VERSION ${ROOT_VERSION}
      SOVERSION ${ROOT_MAJOR_VERSION}
      SUFFIX ${libsuffix}
      PREFIX ${libprefix} )
else()
  set(ROOT_LIBRARY_PROPERTIES ${ROOT_LIBRARY_PROPERTIES}
      SUFFIX ${libsuffix}
      PREFIX ${libprefix}
      IMPORT_PREFIX ${libprefix} )
endif()

if(APPLE)
  if(gnuinstall)
    set(ROOT_LIBRARY_PROPERTIES ${ROOT_LIBRARY_PROPERTIES}
         INSTALL_NAME_DIR "${CMAKE_INSTALL_FULL_LIBDIR}"
         BUILD_WITH_INSTALL_RPATH ON)
  else()
    set(ROOT_LIBRARY_PROPERTIES ${ROOT_LIBRARY_PROPERTIES}
         INSTALL_NAME_DIR "@rpath"
         BUILD_WITH_INSTALL_RPATH ON)
  endif()
endif()

#---Modify the behaviour for local and non-local builds--------------------------------------------

if(CMAKE_PROJECT_NAME STREQUAL ROOT)
  set(rootcint_cmd rootcling_tmp)
  set(rlibmap_cmd rlibmap)
  set(genreflex_cmd genreflex)
  set(ROOTCINTDEP rootcling_tmp)
else()
  set(rootcint_cmd rootcling)
  set(rlibmap_cmd rlibmap)
  set(genreflex_cmd genreflex)
  set(ROOTCINTDEP)
endif()

set(CMAKE_VERBOSE_MAKEFILES OFF)
set(CMAKE_INCLUDE_CURRENT_DIR OFF)

include(CMakeParseArguments)

#---------------------------------------------------------------------------------------------------
#---ROOT_GLOB_FILES( <variable> [REALTIVE path] [FILTER regexp] <sources> ...)
#---------------------------------------------------------------------------------------------------
function(ROOT_GLOB_FILES variable)
  CMAKE_PARSE_ARGUMENTS(ARG "" "RELATIVE;FILTER" "" ${ARGN})
  if(ARG_RELATIVE)
    file(GLOB _sources RELATIVE ${ARG_RELATIVE} ${ARG_UNPARSED_ARGUMENTS})
  else()
    file(GLOB _sources ${ARG_UNPARSED_ARGUMENTS})
  endif()
  if(ARG_FILTER)
    foreach(s ${_sources})
      if(s MATCHES ${ARG_FILTER})
        list(REMOVE_ITEM _sources ${s})
      endif()
    endforeach()
  endif()
  set(${variable} ${_sources} PARENT_SCOPE)
endfunction()

function(ROOT_GLOB_SOURCES variable)
  ROOT_GLOB_FILES(_sources FILTER "(^|/)G__" ${ARGN})
  set(${variable} ${_sources} PARENT_SCOPE)
endfunction()

function(ROOT_GLOB_HEADERS variable)
  ROOT_GLOB_FILES(_sources FILTER "LinkDef" ${ARGN})
  set(${variable} ${_sources} PARENT_SCOPE)
endfunction()

#---------------------------------------------------------------------------------------------------
#---ROOT_GET_SOURCES( <variable> cwd <sources> ...)
#---------------------------------------------------------------------------------------------------
function(ROOT_GET_SOURCES variable cwd )
  set(sources)
  foreach( fp ${ARGN})
    if( IS_ABSOLUTE ${fp})
      file(GLOB files ${fp})
    else()
      file(GLOB files RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${cwd}/${fp})
    endif()
    if(files)
      foreach(s ${files})
        if(fp MATCHES "[*]" AND s MATCHES "(^|/)G__") # Eliminate G__* files only when using wildcards
        else()
          set(sources ${sources} ${s})
        endif()
      endforeach()
    else()
      if(fp MATCHES "(^|/)G__")
        set(sources ${fp} ${sources})
      else()
        set(sources ${sources} ${fp})
      endif()
    endif()
  endforeach()
  set(${variable} ${sources} PARENT_SCOPE)
endfunction()

#---------------------------------------------------------------------------------------------------
#---REFLEX_GENERATE_DICTIONARY( dictionary headerfiles SELECTION selectionfile OPTIONS opt1 opt2 ...)
#---------------------------------------------------------------------------------------------------
macro(REFLEX_GENERATE_DICTIONARY dictionary)
  CMAKE_PARSE_ARGUMENTS(ARG "" "SELECTION" "OPTIONS" ${ARGN})
  #---Get List of header files---------------
  set(headerfiles)
  foreach(fp ${ARG_UNPARSED_ARGUMENTS})
    file(GLOB files inc/${fp})
    if(files)
      foreach(f ${files})
        if(NOT f MATCHES LinkDef)
          set(headerfiles ${headerfiles} ${f})
        endif()
      endforeach()
    else()
      set(headerfiles ${headerfiles} ${fp})
    endif()
  endforeach()
  #---Get Selection file------------------------------------
  if(IS_ABSOLUTE ${ARG_SELECTION})
    set(selectionfile ${ARG_SELECTION})
  else()
    set(selectionfile ${CMAKE_CURRENT_SOURCE_DIR}/${ARG_SELECTION})
  endif()

  set(gensrcdict ${dictionary}.cxx)
  set(rootmapname ${dictionary}Dict.rootmap)
  set(rootmapopts --rootmap=${rootmapname} --rootmap-lib=${libprefix}${dictionary}Dict)

  set(include_dirs -I${CMAKE_CURRENT_SOURCE_DIR})
  get_directory_property(incdirs INCLUDE_DIRECTORIES)
  foreach( d ${incdirs})
   set(include_dirs ${include_dirs} -I${d})
  endforeach()

  get_directory_property(defs COMPILE_DEFINITIONS)
  foreach( d ${defs})
   set(definitions ${definitions} -D${d})
  endforeach()

  add_custom_command(
    OUTPUT ${gensrcdict} ${rootmapname}
    COMMAND ${ROOT_genreflex_cmd}
    ARGS ${headerfiles} -o ${gensrcdict} ${rootmapopts} --select=${selectionfile}
         --gccxmlpath=${GCCXML_home}/bin ${ARG_OPTIONS} ${include_dirs} ${definitions}
    DEPENDS ${headerfiles} ${selectionfile})

  #---roottest compability---------------------------------
  if(CMAKE_ROOTTEST_DICT)
    ROOTTEST_TARGETNAME_FROM_FILE(targetname ${dictionary})

    set(targetname "${targetname}-dictgen")

    # Target onepcm is only available, if roottest is built within root.
    if(TARGET onepcm)
      add_custom_target(${targetname} ALL DEPENDS ${gensrcdict} onepcm)
    else()
      add_custom_target(${targetname} ALL DEPENDS ${gensrcdict})
    endif()
  else()
    set(targetname "${dictionary}-dictgen")
    # Creating this target at ALL level enables the possibility to generate dictionaries (genreflex step)
    # well before the dependent libraries of the dictionary are build
    add_custom_target(${targetname} ALL DEPENDS ${gensrcdict})
  endif()

endmacro()

#---------------------------------------------------------------------------------------------------
#---ROOT_GENERATE_DICTIONARY( dictionary headerfiles MODULE module DEPENDENCIES dep1 dep2
#                                                    STAGE1 LINKDEF linkdef OPTIONS opt1 opt2 ...)
#---------------------------------------------------------------------------------------------------
function(ROOT_GENERATE_DICTIONARY dictionary)
  CMAKE_PARSE_ARGUMENTS(ARG "STAGE1;MULTIDICT" "MODULE" "LINKDEF;OPTIONS;DEPENDENCIES" ${ARGN})

  #---roottest compability---------------------------------
  if(CMAKE_ROOTTEST_DICT)
    set(CMAKE_INSTALL_LIBDIR ${CMAKE_CURRENT_BINARY_DIR})
    set(libprefix "")
  endif()

  #---Get the list of header files-------------------------
  set(headerfiles)
  foreach(fp ${ARG_UNPARSED_ARGUMENTS})
    file(GLOB files inc/${fp})
    if(files)
      foreach(f ${files})
        if(NOT f MATCHES LinkDef)
          set(headerfiles ${headerfiles} ${f})
        endif()
      endforeach()
    else()
      set(headerfiles ${headerfiles} ${fp})
    endif()
  endforeach()
  string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/inc/" ""  rheaderfiles "${headerfiles}")
  #---Get the list of include directories------------------
  get_directory_property(incdirs INCLUDE_DIRECTORIES)
  if(CMAKE_PROJECT_NAME STREQUAL ROOT)
    set(includedirs -I${CMAKE_SOURCE_DIR}
                    -I${CMAKE_CURRENT_SOURCE_DIR}/inc
                    -I${CMAKE_SOURCE_DIR}/io/io/inc
                    -I${CMAKE_BINARY_DIR}/include)
  else()
    set(includedirs -I${CMAKE_CURRENT_SOURCE_DIR}/inc)
  endif()
  foreach( d ${incdirs})
   set(includedirs ${includedirs} -I${d})
  endforeach()
  #---Get the list of definitions---------------------------
  get_directory_property(defs COMPILE_DEFINITIONS)
  foreach( d ${defs})
   if(NOT d MATCHES "=")
     set(definitions ${definitions} -D${d})
   endif()
  endforeach()
  #---Get LinkDef.h file------------------------------------
  foreach( f ${ARG_LINKDEF})
    if( IS_ABSOLUTE ${f})
      set(_linkdef ${_linkdef} ${f})
    else()
      if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/inc/${f})
        set(_linkdef ${_linkdef} ${CMAKE_CURRENT_SOURCE_DIR}/inc/${f})
      else()
        set(_linkdef ${_linkdef} ${CMAKE_CURRENT_SOURCE_DIR}/${f})
      endif()
    endif()
  endforeach()

  #---Build the names for library, pcm and rootmap file ----
  get_filename_component(dict_base_name ${dictionary} NAME_WE)
  if(dict_base_name MATCHES "^G__")
    string(SUBSTRING ${dictionary} 3 -1 deduced_arg_module)
  else()
    set(deduced_arg_module ${dict_base_name})
  endif()

  if(ARG_MODULE)
    set(library_name ${libprefix}${ARG_MODULE}${libsuffix})
    if(ARG_MULTIDICT)
      set(newargs -s ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${library_name} -multiDict)
      set(pcm_name ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${libprefix}${ARG_MODULE}_${dictionary}_rdict.pcm)
      set(rootmap_name ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${libprefix}${deduced_arg_module}.rootmap)
    else()
      set(newargs -s ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${library_name})
      set(pcm_name ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${libprefix}${ARG_MODULE}_rdict.pcm)
      set(rootmap_name ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${libprefix}${ARG_MODULE}.rootmap)
    endif()
  else()
    set(library_name ${libprefix}${deduced_arg_module}${libsuffix})
    set(pcm_name ${dictionary}_rdict.pcm)
    set(rootmap_name ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${libprefix}${deduced_arg_module}.rootmap)
  endif()

  set(rootmapargs -rml ${library_name} -rmf ${rootmap_name})

  #---Get the library and module dependencies-----------------
  if(ARG_DEPENDENCIES)
    foreach(dep ${ARG_DEPENDENCIES})
      set(newargs ${newargs} -m  ${libprefix}${dep}_rdict.pcm)
    endforeach()
  endif()

  #---what rootcling command to use--------------------------
  if(ARG_STAGE1)
    set(command rootcling_tmp)
    set(pcm_name)
  else()
    if(CMAKE_PROJECT_NAME STREQUAL ROOT)
      set(command rootcling -rootbuild)
    else()
      set(command rootcling)
    endif()
  endif()

  #---call rootcint------------------------------------------
  add_custom_command(OUTPUT ${dictionary}.cxx ${pcm_name} ${rootmap_name}
                     COMMAND ${command} -f  ${dictionary}.cxx ${newargs} ${rootmapargs}
                                        -c ${ARG_OPTIONS} ${definitions} ${includedirs} ${rheaderfiles} ${_linkdef}
                     DEPENDS ${headerfiles} ${_linkdef} ${ROOTCINTDEP})
  get_filename_component(dictname ${dictionary} NAME)

  #---roottest compability
  if(CMAKE_ROOTTEST_DICT)
    add_custom_target(${dictname} ALL DEPENDS ${dictionary}.cxx)
  else()
    add_custom_target(${dictname} DEPENDS ${dictionary}.cxx)

    set_property(GLOBAL APPEND PROPERTY ROOT_DICTIONARY_TARGETS ${dictname})
    set_property(GLOBAL APPEND PROPERTY ROOT_DICTIONARY_FILES ${CMAKE_CURRENT_BINARY_DIR}/${dictionary}.cxx)

    if(ARG_STAGE1)
      install(FILES ${rootmap_name}
                    DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT libraries)
    else()
      install(FILES ${pcm_name} ${rootmap_name}
                    DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT libraries)
    endif()
  endif()
endfunction()


#---------------------------------------------------------------------------------------------------
#---ROOT_LINKER_LIBRARY( <name> source1 source2 ...[TYPE STATIC|SHARED] [DLLEXPORT] LIBRARIES library1 library2 ...)
#---------------------------------------------------------------------------------------------------
function(ROOT_LINKER_LIBRARY library)
  CMAKE_PARSE_ARGUMENTS(ARG "DLLEXPORT;CMAKENOEXPORT" "TYPE" "LIBRARIES;DEPENDENCIES"  ${ARGN})
  ROOT_GET_SOURCES(lib_srcs src ${ARG_UNPARSED_ARGUMENTS})
  if(NOT ARG_TYPE)
    set(ARG_TYPE SHARED)
  endif()
  if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/inc)
    include_directories(BEFORE ${CMAKE_CURRENT_SOURCE_DIR}/inc)
  endif()
  include_directories(${CMAKE_BINARY_DIR}/include)                # This is a copy and certainly should last one
  set(library_name ${library})
  if(TARGET ${library})
    message("Target ${library} already exists. Renaming target name to ${library}_new")
    set(library ${library}_new)
  endif()
  if(WIN32 AND ARG_TYPE STREQUAL SHARED AND NOT ARG_DLLEXPORT)
    #---create a list of all the object files-----------------------------
    if(CMAKE_GENERATOR MATCHES "Visual Studio")
      #foreach(src1 ${lib_srcs})
      #  if(NOT src1 MATCHES "[.]h$|[.]icc$|[.]hxx$|[.]hpp$")
      #    string (REPLACE ${CMAKE_CURRENT_SOURCE_DIR} "" src2 ${src1})
      #    string (REPLACE ${CMAKE_CURRENT_BINARY_DIR} "" src3 ${src2})
      #    string (REPLACE ".." "__" src ${src3})
      #    get_filename_component(name ${src} NAME_WE)
      #    set(lib_objs ${lib_objs} ${library}.dir/${CMAKE_CFG_INTDIR}/${name}.obj)
      #  endif()
      #endforeach()
	  set(lib_objs ${lib_objs} ${library}.dir/${CMAKE_CFG_INTDIR}/*.obj)
    else()
      foreach(src1 ${lib_srcs})
        if(NOT src1 MATCHES "[.]h$|[.]icc$|[.]hxx$|[.]hpp$")
          string (REPLACE ${CMAKE_CURRENT_SOURCE_DIR} "" src2 ${src1})
          string (REPLACE ${CMAKE_CURRENT_BINARY_DIR} "" src3 ${src2})
          string (REPLACE ".." "__" src ${src3})
          get_filename_component(name ${src} NAME)
          get_filename_component(path ${src} PATH)
          set(lib_objs ${lib_objs} ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${library}.dir/${path}/${name}.obj)
        endif()
      endforeach()
    endif()
    #---create a shared library with the .def file------------------------
    add_library(${library} SHARED ${lib_srcs})
    target_link_libraries(${library} ${ARG_LIBRARIES} ${ARG_DEPENDENCIES})
    set_target_properties(${library} PROPERTIES ${ROOT_LIBRARY_PROPERTIES} LINK_FLAGS -DEF:${library}.def)
    #---set the .def file as generated------------------------------------
    set_source_files_properties(${library}.def PROPERTIES GENERATED 1)
    #---create a custom pre-link command that runs bindexplib
    add_custom_command(TARGET ${library} PRE_LINK
                       COMMAND bindexplib
                       ARGS -o ${library}.def ${libprefix}${library} ${lib_objs}
                       DEPENDS bindexplib )
  else()
    add_library( ${library} ${ARG_TYPE} ${lib_srcs})
    if(ARG_TYPE STREQUAL SHARED)
      set_target_properties(${library} PROPERTIES  ${ROOT_LIBRARY_PROPERTIES} )
    endif()
    if(explicitlink OR ROOT_explicitlink_FOUND)
      target_link_libraries(${library} ${ARG_LIBRARIES} ${ARG_DEPENDENCIES})
    else()
      target_link_libraries(${library} ${ARG_LIBRARIES})
    endif()
  endif()
  if(TARGET G__${library})
    add_dependencies(${library} G__${library})
  endif()
  set_property(GLOBAL APPEND PROPERTY ROOT_EXPORTED_TARGETS ${library})
  set_target_properties(${library} PROPERTIES OUTPUT_NAME ${library_name})
  set_target_properties(${library} PROPERTIES LINK_INTERFACE_LIBRARIES "${ARG_DEPENDENCIES}")
  #----Installation details-------------------------------------------------------
  if(ARG_CMAKENOEXPORT)
    install(TARGETS ${library} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
                               LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
                               ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
                               COMPONENT libraries)
  else()
    install(TARGETS ${library} EXPORT ${CMAKE_PROJECT_NAME}Exports
                               RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
                               LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
                               ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
                               COMPONENT libraries)
    #install(EXPORT ${CMAKE_PROJECT_NAME}Exports DESTINATION cmake/modules)
  endif()
  if(WIN32 AND ARG_TYPE STREQUAL SHARED)
    if(CMAKE_GENERATOR MATCHES "Visual Studio")
      install(FILES ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/Debug/lib${library}.pdb
              CONFIGURATIONS Debug
              DESTINATION ${CMAKE_INSTALL_BINDIR}
              COMPONENT libraries)
      install(FILES ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/RelWithDebInfo/lib${library}.pdb
              CONFIGURATIONS RelWithDebInfo
              DESTINATION ${CMAKE_INSTALL_BINDIR}
              COMPONENT libraries)
    else()
      install(FILES ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/lib${library}.pdb
              CONFIGURATIONS Debug RelWithDebInfo
              DESTINATION ${CMAKE_INSTALL_BINDIR}
              COMPONENT libraries)
    endif()
  endif()
endfunction()

#---------------------------------------------------------------------------------------------------
#---ROOT_OBJECT_LIBRARY( <name> source1 source2 ...)
#---------------------------------------------------------------------------------------------------
function(ROOT_OBJECT_LIBRARY library)
  ROOT_GET_SOURCES(lib_srcs src ${ARGN})
  include_directories(BEFORE ${CMAKE_CURRENT_SOURCE_DIR}/inc)
  include_directories(AFTER ${CMAKE_BINARY_DIR}/include)
  add_library( ${library} OBJECT ${lib_srcs})
  if(lib_srcs MATCHES "(^|/)(G__[^.]*)[.]cxx.*")
     add_dependencies(${library} ${CMAKE_MATCH_2})
  endif()
endfunction()

#---------------------------------------------------------------------------------------------------
#---ROOT_MODULE_LIBRARY( <name> source1 source2 ... [DLLEXPORT] LIBRARIES library1 library2 ...)
#---------------------------------------------------------------------------------------------------
function(ROOT_MODULE_LIBRARY library)
  CMAKE_PARSE_ARGUMENTS(ARG "" "" "LIBRARIES" ${ARGN})
  ROOT_GET_SOURCES(lib_srcs src ${ARG_UNPARSED_ARGUMENTS})
  if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/inc)
    include_directories(BEFORE ${CMAKE_CURRENT_SOURCE_DIR}/inc)
  endif()
  include_directories(${CMAKE_BINARY_DIR}/include)
  add_library( ${library} SHARED ${lib_srcs})
  set_target_properties(${library}  PROPERTIES ${ROOT_LIBRARY_PROPERTIES})
  target_link_libraries(${library} ${ARG_LIBRARIES})
  #----Installation details-------------------------------------------------------
  install(TARGETS ${library} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
                             LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
                             ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
                             COMPONENT libraries)
endfunction()

#---------------------------------------------------------------------------------------------------
#---ROOT_USE_PACKAGE( package )
#---------------------------------------------------------------------------------------------------
macro( ROOT_USE_PACKAGE package )
  if(IntegratedBuild)
    if( EXISTS ${CMAKE_SOURCE_DIR}/${package}/CMakeLists.txt)
      set(_use_packages ${_use_packages} ${package})
      if(EXISTS ${CMAKE_SOURCE_DIR}/${package}/inc )
        include_directories( ${CMAKE_SOURCE_DIR}/${package}/inc )
      endif()
      set_property(GLOBAL APPEND PROPERTY ROOT_BUILDTREE_PACKAGES ${package})
      file(READ ${CMAKE_SOURCE_DIR}/${package}/CMakeLists.txt file_contents)
      string( REGEX MATCHALL "ROOT_USE_PACKAGE[ ]*[(][ ]*([^ )])+" vars ${file_contents})
      foreach( var ${vars})
        string(REGEX REPLACE "ROOT_USE_PACKAGE[ ]*[(][ ]*([^ )])" "\\1" p ${var})
        #---avoid calling the same one at the same directory level ---------------------------------
        list(FIND _use_packages ${p} _done)
        if(_done EQUAL -1)
          ROOT_USE_PACKAGE(${p})
        endif()
      endforeach()
    else()
      find_package(${package})
      GET_PROPERTY(parent DIRECTORY PROPERTY PARENT_DIRECTORY)
      if(parent)
        set(${package}_environment  ${${package}_environment} PARENT_SCOPE)
       else()
        set(${package}_environment  ${${package}_environment} )
      endif()
      include_directories( ${${package}_INCLUDE_DIRS} )
      link_directories( ${${package}_LIBRARY_DIRS} )
    endif()
  endif()
endmacro()

#---------------------------------------------------------------------------------------------------
#---ROOT_GENERATE_ROOTMAP( library LINKDEF linkdef LIBRRARY lib DEPENDENCIES lib1 lib2 )
#---------------------------------------------------------------------------------------------------
function(ROOT_GENERATE_ROOTMAP library)
  return()   #--- No needed anymore
  CMAKE_PARSE_ARGUMENTS(ARG "" "LIBRARY" "LINKDEF;DEPENDENCIES" ${ARGN})
  get_filename_component(libname ${library} NAME_WE)
  get_filename_component(path ${library} PATH)
  set(outfile ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${libprefix}${libname}.rootmap)
  foreach( f ${ARG_LINKDEF})
    if( IS_ABSOLUTE ${f})
      set(_linkdef ${_linkdef} ${f})
    else()
      set(_linkdef ${_linkdef} ${CMAKE_CURRENT_SOURCE_DIR}/inc/${f})
    endif()
  endforeach()
  foreach(d ${ARG_DEPENDENCIES})
    get_filename_component(_ext ${d} EXT)
    if(_ext)
      set(_dependencies ${_dependencies} ${d})
    else()
      set(_dependencies ${_dependencies} ${libprefix}${d}${CMAKE_SHARED_LIBRARY_SUFFIX})
    endif()
  endforeach()
  if(ARG_LIBRARY)
    set(_library ${ARG_LIBRARY})
  else()
    set(_library ${libprefix}${library}${CMAKE_SHARED_LIBRARY_SUFFIX})
  endif()
  #---Build the rootmap file--------------------------------------
  add_custom_command(OUTPUT ${outfile}
                     COMMAND ${rlibmap_cmd} -o ${outfile} -l ${_library} -d ${_dependencies} -c ${_linkdef}
                     DEPENDS ${_linkdef} ${rlibmap_cmd} )
  add_custom_target( ${libprefix}${library}.rootmap ALL DEPENDS  ${outfile})
  set_target_properties(${libprefix}${library}.rootmap PROPERTIES FOLDER RootMaps )
  #---Install the rootmap file------------------------------------
  install(FILES ${outfile} DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT libraries)
endfunction()

#---------------------------------------------------------------------------------------------------
#---ROOT_INSTALL_HEADERS([dir1 dir2 ...] OPTIONS [options])
#---------------------------------------------------------------------------------------------------
function(ROOT_INSTALL_HEADERS)
  CMAKE_PARSE_ARGUMENTS(ARG "" "" "OPTIONS" ${ARGN})
  if( ARG_UNPARSED_ARGUMENTS )
    set(dirs ${ARG_UNPARSED_ARGUMENTS})
  else()
    set(dirs inc/)
  endif()
  foreach(d ${dirs})
    install(DIRECTORY ${d} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
                           COMPONENT headers
                           PATTERN ".svn" EXCLUDE
                           REGEX "LinkDef" EXCLUDE
                           ${ARG_OPTIONS})
    set_property(GLOBAL APPEND PROPERTY ROOT_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/${d})
  endforeach()
endfunction()

#---------------------------------------------------------------------------------------------------
#---ROOT_STANDARD_LIBRARY_PACKAGE(libname DEPENDENCIES lib1 lib2)
#---------------------------------------------------------------------------------------------------
function(ROOT_STANDARD_LIBRARY_PACKAGE libname)
  CMAKE_PARSE_ARGUMENTS(ARG "" "" "DEPENDENCIES" ${ARGN})
  ROOT_GENERATE_DICTIONARY(G__${libname} *.h MODULE ${libname} LINKDEF LinkDef.h)
  ROOT_LINKER_LIBRARY(${libname} *.cxx G__${libname}.cxx DEPENDENCIES ${ARG_DEPENDENCIES})
  ROOT_INSTALL_HEADERS()
endfunction()

#---------------------------------------------------------------------------------------------------
#---ROOT_EXECUTABLE( <name> source1 source2 ... LIBRARIES library1 library2 ...)
#---------------------------------------------------------------------------------------------------
function(ROOT_EXECUTABLE executable)
  CMAKE_PARSE_ARGUMENTS(ARG "CMAKENOEXPORT;NOINSTALL" "" "LIBRARIES;ADDITIONAL_COMPILE_FLAGS"  ${ARGN})
  ROOT_GET_SOURCES(exe_srcs src ${ARG_UNPARSED_ARGUMENTS})
  set(executable_name ${executable})
  if(TARGET ${executable})
    message("Target ${executable} already exists. Renaming target name to ${executable}_new")
    set(executable ${executable}_new)
  endif()
  if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/inc)
    include_directories(BEFORE ${CMAKE_CURRENT_SOURCE_DIR}/inc)
  endif()
  include_directories(${CMAKE_BINARY_DIR}/include)
  add_executable( ${executable} ${exe_srcs})
  target_link_libraries(${executable} ${ARG_LIBRARIES} )
  if(WIN32 AND ${executable} MATCHES .exe)
    set_target_properties(${executable} PROPERTIES SUFFIX "")
  endif()
  set_property(GLOBAL APPEND PROPERTY ROOT_EXPORTED_TARGETS ${executable})
  set_target_properties(${executable} PROPERTIES OUTPUT_NAME ${executable_name})
  if (ARG_ADDITIONAL_COMPILE_FLAGS)
    set_target_properties(${executable} PROPERTIES COMPILE_FLAGS ${ARG_ADDITIONAL_COMPILE_FLAGS})
  endif()
  #----Installation details------------------------------------------------------
  if(NOT ARG_NOINSTALL)
    if(ARG_CMAKENOEXPORT)
      install(TARGETS ${executable} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT applications)
    else()
      install(TARGETS ${executable} EXPORT ${CMAKE_PROJECT_NAME}Exports RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT applications)
    endif()
  endif()
endfunction()

#---------------------------------------------------------------------------------------------------
#---REFLEX_BUILD_DICTIONARY( dictionary headerfiles selectionfile OPTIONS opt1 opt2 ...  LIBRARIES lib1 lib2 ... )
#---------------------------------------------------------------------------------------------------
function(REFLEX_BUILD_DICTIONARY dictionary headerfiles selectionfile )
  CMAKE_PARSE_ARGUMENTS(ARG "" "" "LIBRARIES;OPTIONS" ${ARGN})
  REFLEX_GENERATE_DICTIONARY(${dictionary} ${headerfiles} SELECTION ${selectionfile} OPTIONS ${ARG_OPTIONS})
  add_library(${dictionary}Dict MODULE ${gensrcdict})
  target_link_libraries(${dictionary}Dict ${ARG_LIBRARIES} ${ROOT_Reflex_LIBRARY})
  #----Installation details-------------------------------------------------------
  install(TARGETS ${dictionary}Dict LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
  set(mergedRootMap ${CMAKE_INSTALL_PREFIX}/${lib}/${CMAKE_PROJECT_NAME}Dict.rootmap)
  set(srcRootMap ${CMAKE_CURRENT_BINARY_DIR}/${rootmapname})
  install(CODE "EXECUTE_PROCESS(COMMAND ${merge_rootmap_cmd} --do-merge --input-file ${srcRootMap} --merged-file ${mergedRootMap})")
endfunction()

#---------------------------------------------------------------------------------------------------
#---SET_RUNTIME_PATH( var [LD_LIBRARY_PATH | PATH] )
#---------------------------------------------------------------------------------------------------
function( SET_RUNTIME_PATH var pathname)
  set( dirs ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${CMAKE_CFG_INTDIR})
  get_property(found_packages GLOBAL PROPERTY PACKAGES_FOUND)
  get_property(found_projects GLOBAL PROPERTY PROJECTS_FOUND)
  foreach( package ${found_projects} ${found_packages} )
     foreach( env ${${package}_environment})
         if(env MATCHES "^${pathname}[+]=.*")
            string(REGEX REPLACE "^${pathname}[+]=(.+)" "\\1"  val ${env})
            set(dirs ${dirs} ${val})
         endif()
     endforeach()
  endforeach()
  if(WIN32)
    string(REPLACE ";" "[:]" dirs "${dirs}")
  else()
    string(REPLACE ";" ":" dirs "${dirs}")
  endif()
  set(${var} "${dirs}" PARENT_SCOPE)
endfunction()

#---------------------------------------------------------------------------------------------------
#---ROOT_CHECK_OUT_OF_SOURCE_BUILD( )
#---------------------------------------------------------------------------------------------------
macro(ROOT_CHECK_OUT_OF_SOURCE_BUILD)
 string(COMPARE EQUAL ${CMAKE_SOURCE_DIR} ${CMAKE_BINARY_DIR} insource)
  if(insource)
     file(REMOVE_RECURSE ${CMAKE_SOURCE_DIR}/Testing)
     file(REMOVE ${CMAKE_SOURCE_DIR}/DartConfiguration.tcl)
     message(FATAL_ERROR "ROOT should be installed as an out of source build, to keep the source directory clean. Please create a extra build directory and run the command 'cmake <path_to_source_dir>' in this newly created directory. You have also to delete the directory CMakeFiles and the file CMakeCache.txt in the source directory. Otherwise cmake will complain even if you run it from an out-of-source directory.")
  endif()
endmacro()

#----------------------------------------------------------------------------
# function ROOT_ADD_TEST( <name> COMMAND cmd [arg1... ]
#                        [PRECMD cmd [arg1...]] [POSTCMD cmd [arg1...]]
#                        [OUTPUT outfile] [ERROR errfile]
#                        [ENVIRONMENT var1=val1 var2=val2 ...
#                        [DEPENDS test1 ...]
#                        [TIMEOUT seconds]
#                        [DEBUG]
#                        [SOURCE_DIR dir] [BINARY_DIR dir]
#                        [WORKING_DIR dir]
#                        [BUILD target] [PROJECT project]
#                        [PASSREGEX exp] [FAILREGEX epx]
#                        [PASSRC code])
#
function(ROOT_ADD_TEST test)
  CMAKE_PARSE_ARGUMENTS(ARG "DEBUG;WILLFAIL;CHECKOUT;CHECKERR"
                             "TIMEOUT;BUILD;OUTPUT;ERROR;SOURCE_DIR;BINARY_DIR;WORKING_DIR;PROJECT;PASSRC"
                             "COMMAND;DIFFCMD;OUTCNV;OUTCNVCMD;PRECMD;POSTCMD;ENVIRONMENT;COMPILEMACROS;DEPENDS;PASSREGEX;CMPOUTPUT;FAILREGEX;LABELS"
                            ${ARGN})

  #- Handle COMMAND argument
  list(LENGTH ARG_COMMAND _len)
  if(_len LESS 1)
    if(NOT ARG_BUILD)
      message(FATAL_ERROR "ROOT_ADD_TEST: command is mandatory (without build)")
    endif()
  else()
    list(GET ARG_COMMAND 0 _prg)
    list(REMOVE_AT ARG_COMMAND 0)

    find_program(_exe ${_prg})

    if(_exe)
      set(_cmd ${_exe} ${ARG_COMMAND})
    else()
      if(TARGET ${_prg})
	    set(_prg "$<TARGET_FILE:${_prg}>")
	  else()
        if(NOT IS_ABSOLUTE ${_prg})
          set(_prg ${CMAKE_CURRENT_BINARY_DIR}/${_prg})
        endif()
	  endif()
      set(_cmd ${_prg} ${ARG_COMMAND})
    endif()

    unset(_exe CACHE)

    string(REPLACE ";" "^" _cmd "${_cmd}")
  endif()

  set(_command ${CMAKE_COMMAND} -DCMD=${_cmd})

  #- Handle PRE and POST commands
  if(ARG_PRECMD)
    string(REPLACE ";" "^" _pre "${ARG_PRECMD}")
    set(_command ${_command} -DPRE=${_pre})
  endif()

  if(ARG_POSTCMD)
    string(REPLACE ";" "^" _post "${ARG_POSTCMD}")
    set(_command ${_command} -DPOST=${_post})
  endif()

  #- Handle OUTPUT, ERROR, DEBUG arguments
  if(ARG_OUTPUT)
    set(_command ${_command} -DOUT=${ARG_OUTPUT})
  endif()

  if(ARG_CMPOUTPUT)
    set(_command ${_command} -DCMPOUTPUT=${ARG_CMPOUTPUT})
  endif()

  if(ARG_ERROR)
    set(_command ${_command} -DERR=${ARG_ERROR})
  endif()

  if(ARG_WORKING_DIR)
    set(_command ${_command} -DCWD=${ARG_WORKING_DIR})
  else()
    set(_command ${_command} -DCWD=${CMAKE_CURRENT_BINARY_DIR})
  endif()

  if(ARG_DEBUG)
    set(_command ${_command} -DDBG=ON)
  endif()

  if(ARG_PASSRC)
    set(_command ${_command} -DRC=${ARG_PASSRC})
  endif()

  if(ARG_OUTCNVCMD)
    string(REPLACE ";" "^" _outcnvcmd "${ARG_OUTCNVCMD}")
    set(_command ${_command} -DCNVCMD=${_outcnvcmd})
  endif()

  if(ARG_OUTCNV)
    string(REPLACE ";" "^" _outcnv "${ARG_OUTCNV}")
    set(_command ${_command} -DCNV=${_outcnv})
  endif()

  if(ARG_DIFFCMD)
    string(REPLACE ";" "^" _diff_cmd "${ARG_DIFFCMD}")
    set(_command ${_command} -DDIFFCMD=${_diff_cmd})
  endif()

  if(ARG_CHECKOUT)
    set(_command ${_command} -DCHECKOUT=true)
  endif()

  if(ARG_CHECKERR)
    set(_command ${_command} -DCHECKERR=true)
  endif()

  #- Handle ENVIRONMENT argument
  if(ARG_ENVIRONMENT)
    string(REPLACE ";" "#" _env "${ARG_ENVIRONMENT}")
    string(REPLACE "=" "@" _env "${_env}")
    set(_command ${_command} -DENV=${_env})
  endif()

  #- Locate the test driver
  find_file(ROOT_TEST_DRIVER RootTestDriver.cmake PATHS ${CMAKE_MODULE_PATH})
  if(NOT ROOT_TEST_DRIVER)
    message(FATAL_ERROR "ROOT_ADD_TEST: RootTestDriver.cmake not found!")
  endif()
  set(_command ${_command} -P ${ROOT_TEST_DRIVER})

  if(ARG_WILLFAIL)
    set(test ${test}_WILL_FAIL)
  endif()

  #- Now we can actually add the test
  if(ARG_BUILD)
    if(NOT ARG_SOURCE_DIR)
      set(ARG_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    endif()
    if(NOT ARG_BINARY_DIR)
      set(ARG_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR})
    endif()
    if(NOT ARG_PROJECT)
       if(NOT PROJECT_NAME STREQUAL "ROOT")
         set(ARG_PROJECT ${PROJECT_NAME})
       else()
         set(ARG_PROJECT ${ARG_BUILD})
       endif()
    endif()
    add_test(NAME ${test} COMMAND ${CMAKE_CTEST_COMMAND}
      --build-and-test  ${ARG_SOURCE_DIR} ${ARG_BINARY_DIR}
      --build-generator ${CMAKE_GENERATOR}
      --build-makeprogram ${CMAKE_MAKE_PROGRAM}
      --build-target ${ARG_BUILD}
      --build-project ${ARG_PROJECT}
      --build-config $<CONFIGURATION>
      --build-noclean
      --test-command ${_command} )
    set_property(TEST ${test} PROPERTY ENVIRONMENT ROOT_DIR=${CMAKE_BINARY_DIR})
  else()
    add_test(NAME ${test} COMMAND ${_command})
  endif()

  #- Handle TIMOUT and DEPENDS arguments
  if(ARG_TIMEOUT)
    set_property(TEST ${test} PROPERTY TIMEOUT ${ARG_TIMEOUT})
  endif()

  if(ARG_DEPENDS)
    set_property(TEST ${test} PROPERTY DEPENDS ${ARG_DEPENDS})
  endif()

  if(ARG_PASSREGEX)
    set_property(TEST ${test} PROPERTY PASS_REGULAR_EXPRESSION ${ARG_PASSREGEX})
  endif()

  if(ARG_FAILREGEX)
    set_property(TEST ${test} PROPERTY FAIL_REGULAR_EXPRESSION ${ARG_FAILREGEX})
  endif()

  if(ARG_WILLFAIL)
    set_property(TEST ${test} PROPERTY WILL_FAIL true)
  endif()

  if(ARG_LABELS)
    set_tests_properties(${test} PROPERTIES LABELS "${ARG_LABELS}")
  endif()

endfunction()

#----------------------------------------------------------------------------
# function ROOT_ADD_TEST_SUBDIRECTORY( <name> )
function(ROOT_ADD_TEST_SUBDIRECTORY subdir)
  file(RELATIVE_PATH subdir ${CMAKE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/${subdir})
  set_property(GLOBAL APPEND PROPERTY ROOT_TEST_SUBDIRS ${subdir})
endfunction()
