# Best-effort .pyi stub generation, invoked as a POST_BUILD step.
# Never fails the build: a missing/broken pybind11-stubgen just warns and the
# wheel ships without stubs. Inputs: MODULE_DIR (dir containing the built
# cupoch module), OUT_DIR (stub output root; OUT_DIR/cupoch/*.pyi).
file(MAKE_DIRECTORY "${OUT_DIR}/cupoch")
execute_process(
    COMMAND ${CMAKE_COMMAND} -E env "PYTHONPATH=${MODULE_DIR}"
            pybind11-stubgen cupoch
                --no-setup-py
                --root-module-suffix=
                --ignore-invalid=all
                --output-dir=${OUT_DIR}
    RESULT_VARIABLE _stubgen_rc)
if (NOT _stubgen_rc EQUAL 0)
    message(WARNING
        "pybind11-stubgen failed (exit ${_stubgen_rc}); wheel will ship without .pyi stubs")
endif ()
