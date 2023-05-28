
add_library(webgpu SHARED ${DAWN_PLACEHOLDER_FILE})
common_compile_options(webgpu)
target_link_libraries(webgpu PRIVATE dawn_native)
target_link_libraries(webgpu PUBLIC dawn_headers)
target_compile_definitions(webgpu PRIVATE WGPU_IMPLEMENTATION WGPU_SHARED_LIBRARY)
target_sources(webgpu PRIVATE ${WEBGPU_DAWN_NATIVE_PROC_GEN})
