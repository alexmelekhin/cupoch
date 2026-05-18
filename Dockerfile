# syntax=docker/dockerfile:1

# CUDA image version tag (nvidia/cuda:<CUDA_VERSION>-devel-ubuntu24.04).
ARG CUDA_VERSION=12.8.0
# Python version uv builds the wheel for (3.10 / 3.11 / 3.12 / 3.13).
ARG PYTHON_VERSION=3.12
# CUDA architecture(s) to compile device code for: a single value (86), a
# CMake keyword (native / all-major), or a ;-separated list (75;80;86).
ARG CUDA_ARCHITECTURES=86

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu24.04 AS builder

ARG PYTHON_VERSION=3.12
ARG CUDA_ARCHITECTURES=86

WORKDIR /work/cupoch

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tokyo

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        git \
        libxinerama-dev \
        libxcursor-dev \
        libglu1-mesa-dev \
        xorg-dev && \
    rm -rf /var/lib/apt/lists/*

# The pinned RMM submodule needs the NVTX3 C++ header (nvtx3/nvtx3.hpp);
# CUDA >= 12.x images ship only the legacy NVTX v2 C headers. Vendor the
# official header-only NVTX3 and put it on the compiler include path.
RUN git clone --depth 1 -b release-v3 https://github.com/NVIDIA/NVTX.git /opt/nvtx
ENV CPATH="/opt/nvtx/c/include"

# uv: build frontend + Python toolchain manager (provides the requested
# CPython, so no system python-dev is needed).
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

COPY . .

# scikit-build-core passes these through to CMake (see pyproject.toml).
ENV SKBUILD_CMAKE_DEFINE="BUILD_GLEW=ON;BUILD_GLFW=ON;BUILD_PNG=ON;BUILD_JSONCPP=ON"
# Force the Make generator: scikit-build-core defaults to Ninja, but cupoch's
# third-party ExternalProjects (e.g. ext_turbojpeg) declare no BUILD_BYPRODUCTS,
# so their file-path libs only resolve under Make.
ENV CMAKE_GENERATOR="Unix Makefiles"

# CMAKE_CUDA_ARCHITECTURES goes via CMAKE_ARGS (shlex-parsed by
# scikit-build-core), not SKBUILD_CMAKE_DEFINE: the latter splits on ';',
# which would shred a multi-arch list like 75;80;86.
RUN uv python install ${PYTHON_VERSION} && \
    CMAKE_ARGS="-DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES}" \
    uv build --wheel --python ${PYTHON_VERSION}

# Minimal final stage holding only the built wheel, so it can be exported with:
#   docker build --output type=local,dest=./dist .
FROM scratch AS export
COPY --from=builder /work/cupoch/dist/ /
