# syntax=docker/dockerfile:1

# CUDA image version tag (nvidia/cuda:<CUDA_VERSION>-devel-ubuntu24.04).
ARG CUDA_VERSION=12.8.0
# Python version uv builds the wheel for (3.10 / 3.11 / 3.12 / 3.13).
ARG PYTHON_VERSION=3.12

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu24.04 AS builder

ARG PYTHON_VERSION=3.12

WORKDIR /work/cupoch

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tokyo

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        libxinerama-dev \
        libxcursor-dev \
        libglu1-mesa-dev \
        xorg-dev && \
    rm -rf /var/lib/apt/lists/*

# uv: build frontend + Python toolchain manager (provides the requested
# CPython, so no system python-dev is needed).
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

COPY . .

# scikit-build-core passes these through to CMake (see pyproject.toml).
ENV SKBUILD_CMAKE_DEFINE="BUILD_GLEW=ON;BUILD_GLFW=ON;BUILD_PNG=ON;BUILD_JSONCPP=ON"

RUN uv python install ${PYTHON_VERSION} && \
    uv build --wheel --python ${PYTHON_VERSION}

# Minimal final stage holding only the built wheel, so it can be exported with:
#   docker build --output type=local,dest=./dist .
FROM scratch AS export
COPY --from=builder /work/cupoch/dist/ /
