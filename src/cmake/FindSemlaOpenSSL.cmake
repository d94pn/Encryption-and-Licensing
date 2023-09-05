if (USE_DOWNLOADED_OPENSSL_BUILD)
    if(NOT DOWNLOADED_OPENSSL_BUILD_URL)
        message(FATAL_ERROR "DOWNLOADED_OPENSSL_BUILD_URL not set")
    endif()
    if(NOT DOWNLOADED_OPENSSL_BUILD_EXPECTED_HASH_SHA256)
        message(FATAL_ERROR "DOWNLOADED_OPENSSL_BUILD_EXPECTED_HASH_SHA256 not set")
    endif()

    string(REGEX REPLACE ".*/" "" DOWNLOADED_OPENSSL_BUILD_FILENAME ${DOWNLOADED_OPENSSL_BUILD_URL})

    file(DOWNLOAD
        ${DOWNLOADED_OPENSSL_BUILD_URL}
        ${DOWNLOADED_OPENSSL_BUILD_FILENAME}
        EXPECTED_HASH SHA256=${DOWNLOADED_OPENSSL_BUILD_EXPECTED_HASH_SHA256}
        TLS_VERIFY ON
        NETRC OPTIONAL
    )
    file(ARCHIVE_EXTRACT INPUT ${DOWNLOADED_OPENSSL_BUILD_FILENAME}
        DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/openssl
    )
    add_library(ssl STATIC IMPORTED)
    add_library(crypto STATIC IMPORTED)
    file(GLOB LIBSSL_IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/openssl/lib/libssl*${CMAKE_STATIC_LIBRARY_SUFFIX})
    file(GLOB LIBCRYPTO_IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/openssl/lib/libcrypto*${CMAKE_STATIC_LIBRARY_SUFFIX})
    set_target_properties(ssl PROPERTIES IMPORTED_LOCATION ${LIBSSL_IMPORTED_LOCATION})
    set_target_properties(crypto PROPERTIES IMPORTED_LOCATION ${LIBCRYPTO_IMPORTED_LOCATION})
    set(DOWNLOADED_OPENSSL_BUILD_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/openssl/include)
    target_include_directories(crypto INTERFACE ${DOWNLOADED_OPENSSL_BUILD_INCLUDE_DIR})
    target_include_directories(ssl INTERFACE ${DOWNLOADED_OPENSSL_BUILD_INCLUDE_DIR})
    message(STATUS "Will use pre-built OpenSSL from ${DOWNLOADED_OPENSSL_BUILD_URL}")
elseif (USE_CUSTOM_OPENSSL_SUBDIRECTORY)
    if (NOT CUSTOM_OPENSSL_SUBDIRECTORY)
        message(FATAL_ERROR "CUSTOM_OPENSSL_SUBDIRECTORY not set (when USE_CUSTOM_OPENSSL_SUBDIRECTORY is set)")
    endif()
    if (NOT CUSTOM_OPENSSL_SUBDIRECTORY_LIBRARY_TYPE)
        message(FATAL_ERROR "CUSTOM_OPENSSL_SUBDIRECTORY_LIBRARY_TYPE not set (when USE_CUSTOM_OPENSSL_SUBDIRECTORY is set)")
    endif()
    if (NOT (
        CUSTOM_OPENSSL_SUBDIRECTORY_LIBRARY_TYPE STREQUAL "SHARED"
        OR CUSTOM_OPENSSL_SUBDIRECTORY_LIBRARY_TYPE STREQUAL "STATIC"
    ))
        message(FATAL_ERROR "CUSTOM_OPENSSL_SUBDIRECTORY_LIBRARY_TYPE = ${CUSTOM_OPENSSL_SUBDIRECTORY_LIBRARY_TYPE} not equal to either \"SHARED\" or \"STATIC\"")
    endif()
    message(STATUS "Will use OpenSSL from custom OpenSSL subdirectory.")
    add_library(ssl ${CUSTOM_OPENSSL_SUBDIRECTORY_LIBRARY_TYPE} IMPORTED)
    add_library(crypto ${CUSTOM_OPENSSL_SUBDIRECTORY_LIBRARY_TYPE} IMPORTED)
    add_subdirectory(${CUSTOM_OPENSSL_SUBDIRECTORY} ${CMAKE_CURRENT_BINARY_DIR}/openssl)
    get_target_property(LIBSSL_IMPORTED_LOCATION ssl IMPORTED_LOCATION)
    if(NOT LIBSSL_IMPORTED_LOCATION)
        message(FATAL_ERROR "TARGET ssl should add a target property IMPORTED_LOCATION")
    endif()
    get_target_property(LIBCRYPTO_IMPORTED_LOCATION crypto IMPORTED_LOCATION)
    if(NOT LIBCRYPTO_IMPORTED_LOCATION)
        message(FATAL_ERROR "TARGET crypto should add a target property IMPORTED_LOCATION")
    endif()
    if(WIN32)
        get_target_property(LIBSSL_IMPORTED_IMPLIB ssl IMPORTED_IMPLIB)
        if(NOT LIBSSL_IMPORTED_IMPLIB)
            message(FATAL_ERROR "TARGET ssl should add a target property IMPORTED_IMPLIB")
        endif()
        get_target_property(LIBCRYPTO_IMPORTED_IMPLIB crypto IMPORTED_IMPLIB)
        if(NOT LIBCRYPTO_IMPORTED_IMPLIB)
            message(FATAL_ERROR "TARGET crypto should add a target property IMPORTED_IMPLIB")
        endif()
    endif()
    get_target_property(LIBSSL_INTERFACE_INCLUDES ssl INTERFACE_INCLUDE_DIRECTORIES)
    if(NOT LIBSSL_INTERFACE_INCLUDES)
        message(FATAL_ERROR "TARGET ssl should add an interface include directory for the openssl header files")
    endif()
    get_target_property(LIBCRYPTO_INTERFACE_INCLUDES crypto INTERFACE_INCLUDE_DIRECTORIES)
    if(NOT LIBCRYPTO_INTERFACE_INCLUDES)
        message(FATAL_ERROR "TARGET crypto should add an interface include directory for the openssl header files")
    endif()
    if (NOT ("${LIBCRYPTO_INTERFACE_INCLUDES}" STREQUAL "${LIBSSL_INTERFACE_INCLUDES}"))
        message(FATAL_ERROR "TARGET crypto and TARGET ssl should have the same interface include directory for the openssl header files")
    endif()
    include_directories("${LIBCRYPTO_INTERFACE_INCLUDES}")

    get_target_property(LIBSSL_TYPE ssl TYPE)
    if (LIBSSL_TYPE STREQUAL SHARED_LIBRARY AND WIN32)
        # Avoid "no OPENSSL_Applink" run-time error, see the question "I've compiled a program under Windows and it crashes: why?" in https://www.openssl.org/docs/faq.html
        target_compile_definitions(ssl
            INTERFACE INCLUDE_OPENSSL_APPLINK
        )
    endif()

    get_target_property(LIBCRYPTO_TYPE crypto TYPE)
    if (LIBCRYPTO_TYPE STREQUAL SHARED_LIBRARY AND WIN32)
        target_compile_definitions(crypto
            INTERFACE INCLUDE_OPENSSL_APPLINK
        )
    endif()
else()
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/default ${CMAKE_CURRENT_BINARY_DIR}/openssl)
endif()
