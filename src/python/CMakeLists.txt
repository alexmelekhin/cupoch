set(PACKAGE_NAME cupoch)

file(GLOB_RECURSE PY_ALL_SOURCE_FILES "cupoch_pybind/*.cpp")

add_library(${PACKAGE_NAME} SHARED
    ${PY_ALL_SOURCE_FILES}
)

cuda_add_library(cupoch_wrapper cupoch_pybind/device_vector_wrapper.cu
    cupoch_pybind/device_vector_wrapper_bridge.cu
    cupoch_pybind/device_map_wrapper.cu
    cupoch_pybind/collision/collision_bridge.cu
    cupoch_pybind/geometry/graph_bridge.cu
    cupoch_pybind/geometry/keypoint_bridge.cu
    cupoch_pybind/geometry/kdtree_flann_bridge.cu
    cupoch_pybind/geometry/laserscanbuffer_bridge.cu
    cupoch_pybind/geometry/boundingvolume_bridge.cu
    cupoch_pybind/geometry/distancetransform_bridge.cu
    cupoch_pybind/geometry/lineset_bridge.cu
    cupoch_pybind/geometry/meshbase_bridge.cu
    cupoch_pybind/geometry/occupancygrid_bridge.cu
    cupoch_pybind/geometry/pointcloud_bridge.cu
    cupoch_pybind/geometry/trianglemesh_bridge.cu
    cupoch_pybind/geometry/voxelgrid_bridge.cu
    cupoch_pybind/registration/feature_bridge.cu)
target_include_directories(cupoch_wrapper PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)
target_link_libraries(cupoch_wrapper cupoch_geometry)

target_include_directories(${PACKAGE_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)
# Suppress Pybind11 warnings
target_include_directories(${PACKAGE_NAME} SYSTEM PRIVATE
    ${PYBIND11_INCLUDE_DIR} ${PYTHON_INCLUDE_DIRS}
)

target_link_libraries(${PACKAGE_NAME} PRIVATE cupoch_registration
                      cupoch_visualization cupoch_io cupoch_odometry
                      cupoch_planning cupoch_kinematics cupoch_kinfu
                      cupoch_collision cupoch_integration
                      cupoch_imageproc cupoch_geometry
                      cupoch_utility cupoch_wrapper
                      ${3RDPARTY_LIBRARIES} ${CUDA_LIBRARIES})
if (WIN32)
    target_link_libraries(${PACKAGE_NAME} PRIVATE ${PYTHON_LIBRARIES})
endif ()

set_target_properties(${PACKAGE_NAME} PROPERTIES PREFIX "${PYTHON_MODULE_PREFIX}")
set_target_properties(${PACKAGE_NAME} PROPERTIES SUFFIX "${PYTHON_MODULE_EXTENSION}")
set_target_properties(${PACKAGE_NAME} PROPERTIES CXX_VISIBILITY_PRESET "hidden")
set_target_properties(${PACKAGE_NAME} PROPERTIES CUDA_VISIBILITY_PRESET "hidden")
target_compile_options(${PACKAGE_NAME} PUBLIC $<$<COMPILE_LANGUAGE:CXX>:${PYBIND11_CPP_STANDARD}>)

# At `make`: cupoch.so (or the equivalents) will be created at
# PYTHON_COMPILED_MODULE_DIR. The default locaiton is `build/lib/python`
set(PYTHON_COMPILED_MODULE_DIR "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/python")
set_target_properties(${PACKAGE_NAME} PROPERTIES
                      FOLDER "python"
                      LIBRARY_OUTPUT_DIRECTORY "${PYTHON_COMPILED_MODULE_DIR}"
                      ARCHIVE_OUTPUT_DIRECTORY "${PYTHON_COMPILED_MODULE_DIR}")

# Install the compiled module + pure-python package into the wheel.
# scikit-build-core consumes only the "python" component (see pyproject.toml),
# so the static-lib/header install() rules in src/cupoch are excluded.
install(TARGETS ${PACKAGE_NAME}
        LIBRARY DESTINATION cupoch COMPONENT python
        RUNTIME DESTINATION cupoch COMPONENT python)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cupoch/__init__.py
        DESTINATION cupoch COMPONENT python)

# Generate .pyi stubs from the freshly built module. Best-effort: a stubgen
# failure warns but does not fail the wheel build (or pass -DBUILD_STUBS=OFF).
option(BUILD_STUBS "Generate pybind11 .pyi stubs into the wheel" ON)
if (BUILD_STUBS)
    set(STUBS_DIR "${CMAKE_CURRENT_BINARY_DIR}/stubs")
    add_custom_command(TARGET ${PACKAGE_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND}
                -DMODULE_DIR=${PYTHON_COMPILED_MODULE_DIR}
                -DOUT_DIR=${STUBS_DIR}
                -P ${CMAKE_CURRENT_SOURCE_DIR}/run_stubgen.cmake
        COMMENT "Generating cupoch .pyi stubs"
        VERBATIM)
    install(DIRECTORY ${STUBS_DIR}/cupoch/
            DESTINATION cupoch COMPONENT python
            FILES_MATCHING PATTERN "*.pyi")
endif ()
