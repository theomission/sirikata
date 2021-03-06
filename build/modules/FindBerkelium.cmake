#Sirikata
#FindBerkelium.cmake
#
#Copyright (c) 2009, Patrick Horn
#All rights reserved.
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright notice,
#      this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright notice,
#      this list of conditions and the following disclaimer in the documentation
#      and/or other materials provided with the distribution.
#    * Neither the name of the Sirikata nor the names of its contributors
#      may be used to endorse or promote products derived from this software
#      without specific prior written permission.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
#ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
#ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
#ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

SET(BERKELIUM_FOUND FALSE)
IF(EXISTS ${BERKELIUM_ROOT}/include AND EXISTS ${BERKELIUM_ROOT}/lib)
  SET(BERKELIUM_INCLUDE_DIRS ${BERKELIUM_ROOT}/include)
  SET(BERKELIUM_LIBRARY_DIRS ${BERKELIUM_ROOT}/lib)
ELSE()
IF(WIN32)
IF(EXISTS ${BERKELIUM_ROOT}/win32/berkelium.lib AND EXISTS ${BERKELIUM_ROOT}/win32/berkelium.exe)
  SET(BERKELIUM_INCLUDE_DIRS ${BERKELIUM_ROOT}/include)
  SET(BERKELIUM_LIBRARY_DIRS ${BERKELIUM_ROOT}/win32)
ENDIF()
ENDIF()
ENDIF()
IF(BERKELIUM_INCLUDE_DIRS AND BERKELIUM_LIBRARY_DIRS)
  IF(WIN32)  # Windows
    FIND_LIBRARY(BERKELIUM_DEBUG_LIBRARY   NAMES berkelium_d
                 PATH_SUFFIXES "" Debug   PATHS ${BERKELIUM_LIBRARY_DIRS} NO_DEFAULT_PATH)
    FIND_LIBRARY(BERKELIUM_RELEASE_LIBRARY NAMES berkelium
                 PATH_SUFFIXES "" Release PATHS ${BERKELIUM_LIBRARY_DIRS} NO_DEFAULT_PATH)
    SET(BERKELIUM_LIBRARIES)
    IF(BERKELIUM_DEBUG_LIBRARY AND BERKELIUM_RELEASE_LIBRARY)
      SET(BERKELIUM_LIBRARIES debug ${BERKELIUM_DEBUG_LIBRARY} optimized ${BERKELIUM_RELEASE_LIBRARY})
    ELSEIF(BERKELIUM_DEBUG_LIBRARY)
      SET(BERKELIUM_LIBRARIES ${BERKELIUM_DEBUG_LIBRARY})
    ELSEIF(BERKELIUM_RELEASE_LIBRARY)
      SET(BERKELIUM_LIBRARIES ${BERKELIUM_RELEASE_LIBRARY})
    ENDIF(BERKELIUM_DEBUG_LIBRARY AND BERKELIUM_RELEASE_LIBRARY)
  ELSE(WIN32)  # Linux etc
    FIND_LIBRARY(BERKELIUM_LIBRARIES NAMES berkelium PATHS ${BERKELIUM_LIBRARY_DIRS} NO_DEFAULT_PATH)
  ENDIF(WIN32)
  IF(BERKELIUM_LIBRARIES)
    SET(BERKELIUM_FOUND TRUE)
  ENDIF()
ENDIF()
IF(BERKELIUM_FOUND)
  MESSAGE(STATUS "Found Berkelium: headers at ${BERKELIUM_INCLUDE_DIRS}, libraries at ${BERKELIUM_LIBRARIES}")
ENDIF(BERKELIUM_FOUND)
