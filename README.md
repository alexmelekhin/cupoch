<p align="center">
<img src="https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/cupoch_logo.png" width="320" />
</p>

# Robotics with GPU computing

[![Build status](https://github.com/alexmelekhin/cupoch/actions/workflows/ubuntu.yml/badge.svg)](https://github.com/alexmelekhin/cupoch/actions/workflows/ubuntu.yml/badge.svg)
[![Build status](https://github.com/alexmelekhin/cupoch/actions/workflows/windows.yml/badge.svg)](https://github.com/alexmelekhin/cupoch/actions/workflows/windows.yml/badge.svg)

<a href="https://www.buymeacoffee.com/nekanat" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="150" height="40" ></a>

Cupoch is a library that implements rapid 3D data processing for robotics using CUDA.

The goal of this library is to implement fast 3D data computation in robot systems.
For example, it has applications in SLAM, collision avoidance, path planning and tracking.
This repository is based on [Open3D](https://github.com/intel-isl/Open3D).

## Core Features

* 3D data processing and robotics computation using CUDA
    * KNN
        * [WIP] [Optimizing LBVH-Construction and Hierarchy-Traversal to accelerate kNN Queries on Point Clouds using the GPU](https://epub.uni-bayreuth.de/5288/1/cgf.14177.pdf)
        * [flann](https://github.com/flann-lib/flann)
    * Point cloud registration
        * ICP
        * Generalized ICP
        * [Symmetric ICP](https://gfx.cs.princeton.edu/pubs/Rusinkiewicz_2019_ASO/symm_icp.pdf) (Implemented by [@eclipse0922](https://github.com/eclipse0922))
        * [Colored Point Cloud Registration](https://ieeexplore.ieee.org/document/8237287)
        * [Fast Global Registration](http://vladlen.info/papers/fast-global-registration.pdf)
        * [FilterReg](https://arxiv.org/abs/1811.10136)
    * Point cloud features
        * FPFH
        * SHOT
    * Point cloud keypoints
        * ISS
    * Point cloud clustering
        * [G-DBSCAN: A GPU Accelerated Algorithm for Density-based Clustering](https://www.sciencedirect.com/science/article/pii/S1877050913003438)
    * Point cloud/Triangle mesh filtering, down sampling
    * IO
        * Several file types(pcd, ply, stl, obj, urdf)
        * ROS message
    * Create Point Cloud from Laser Scan or RGBD Image
    * Visual Odometry
        * [Real-time visual odometry from dense RGB-D images](https://ieeexplore.ieee.org/document/6130321)
        * [Robust Odometry Estimation for RGB-D Cameras](https://ieeexplore.ieee.org/document/6631104)
    * Kinect Fusion
    * Stereo Matching
    * Collision checking
    * Occupancy grid
    * Distance transform
        * [Parallel Banding Algorithm to Compute Exact Distance Transform with the GPU](https://www.comp.nus.edu.sg/~tants/pba.html)
    * Path finding on graph structure
    * Path planning for collision avoidance
* Support memory pool and managed allocators
* Interactive GUI (OpenGL CUDA interop and [imgui](https://github.com/ocornut/imgui))
* Interoperability between cupoch 3D data and [DLPack](https://github.com/dmlc/dlpack)(Pytorch, Cupy,...) data structure

## Installation

This fork builds wheels with the Ubuntu 24.04 toolchain (x86-64, CUDA 12.x,
Python 3.12). Prebuilt upstream releases are on PyPI:

```
pip install cupoch
```

Or build from source — requires a **recursive clone** (submodules), the
**CUDA toolkit** (`nvcc` on `PATH`), a C++17 compiler, CMake, and the
X11/OpenGL dev headers. Packaging is
[scikit-build-core](https://scikit-build-core.readthedocs.io) (PEP 517) driven
by [uv](https://docs.astral.sh/uv/):

```
sudo apt-get install -y build-essential cmake xorg-dev libxinerama-dev libxcursor-dev libglu1-mesa-dev
git clone https://github.com/alexmelekhin/cupoch.git --recurse
cd cupoch
CMAKE_GENERATOR="Unix Makefiles" uv build --wheel   # -> dist/cupoch-*.whl
uv pip install dist/*.whl
```

> On Linux, `CMAKE_GENERATOR="Unix Makefiles"` is required: the vendored
> third-party ExternalProjects don't declare `BUILD_BYPRODUCTS`, so they don't
> build under scikit-build-core's default Ninja generator.

Pass CMake options (e.g. your GPU's compute capability) at build time via
`SKBUILD_CMAKE_DEFINE`:

```
SKBUILD_CMAKE_DEFINE="CMAKE_CUDA_ARCHITECTURES=86" uv build --wheel
```

For a multi-arch list, `SKBUILD_CMAKE_DEFINE` splits on `;` — pass it via
`CMAKE_ARGS` instead: `CMAKE_ARGS="-DCMAKE_CUDA_ARCHITECTURES=80;86;89" uv build --wheel`.

For an editable / development install:

```
uv pip install -e . --no-build-isolation
```

### Use Docker

Build the wheel inside Docker (CUDA 12.8 / Ubuntu 24.04 / Python 3.12 by
default) and export it to the host `./dist` directory — no local CUDA toolchain
needed:

```sh
docker build --output type=local,dest=./dist .
# choose CUDA / Python versions:
docker build --build-arg CUDA_VERSION=12.8.0 --build-arg PYTHON_VERSION=3.11 \
             --output type=local,dest=./dist .
```

#### Targeting specific GPU architectures

The wheel's device code is compiled for `CUDA_ARCHITECTURES` (default `86`).
Pass a single value, a CMake keyword (`native`, `all-major`), or a
`;`-separated list (quote it so the shell keeps the `;`):

```sh
docker build --build-arg CUDA_ARCHITECTURES=89 --output type=local,dest=./dist .
docker build --build-arg CUDA_ARCHITECTURES="80;86;89;90" \
             --output type=local,dest=./dist .          # one fat wheel
```

The wheel filename does **not** encode the CUDA arch, so building several
archs into the same directory overwrites previous wheels. To build one wheel
per arch into separate `dist/sm_<arch>/` directories, use the helper script:

```sh
./build_wheels.sh                 # archs 80 86 89 90 (defaults)
./build_wheels.sh 86 89           # a subset
CUDA_VERSION=12.9.0 PYTHON_VERSION=3.11 ./build_wheels.sh
```

For an interactive GPU dev container (compose builds the `builder` stage):

```sh
docker compose up -d
# xhost +
docker exec -it cupoch bash
```

### Installing the built wheel in another environment

The produced `cupoch-*-cp312-cp312-linux_x86_64.whl` is a **platform wheel**
(not manylinux). The target environment must satisfy:

- **Arch / OS:** x86-64 Linux only.
- **Python:** CPython **3.12** exactly (the wheel is not `abi3`; build a
  matching wheel for other Python versions).
- **glibc ≥ 2.38** — built on the Ubuntu 24.04 toolchain; Ubuntu 22.04 / 20.04
  are too old.
- **System libraries:** `libGL.so.1` and `libX11.so.6` are hard-linked and
  required even for `import cupoch`. Debian/Ubuntu:
  `apt-get install -y libgl1 libx11-6`.
- **Python deps:** `numpy>=1.26` — installed automatically by pip.
- **CUDA:** the CUDA runtime is **statically linked** — *no CUDA toolkit is
  needed on the target*. Only an **NVIDIA driver supporting CUDA 12.x** is
  required, and only for actual GPU execution (`import cupoch` itself works
  without a GPU).

Minimal install on a fresh Ubuntu 24.04 (or newer) host/container:

```sh
apt-get update && apt-get install -y python3.12 python3-pip libgl1 libx11-6
pip install cupoch-0.2.11.0-cp312-cp312-linux_x86_64.whl
python3.12 -c "import cupoch; print(cupoch.__version__)"
```

For GPU use in containers, run with the NVIDIA Container Toolkit
(`--gpus all`) on any base image with glibc ≥ 2.38 (e.g. `ubuntu:24.04` or
`nvidia/cuda:12.8.0-runtime-ubuntu24.04`).

## Getting Started

Please see how to use cupoch in [Getting Started](https://github.com/alexmelekhin/cupoch/blob/main/docs/getting_started.md) first.

## Results
The figure shows Cupoch's point cloud algorithms speedup over Open3D.
The environment tested on has the following specs:
* Intel Core i7-7700HQ CPU
* Nvidia GTX1070 GPU
* OMP_NUM_THREAD=1

You can get the result by running the example script in your environment.

```sh
cd examples/python/basic
python benchmarks.py
```

If you get the following error when executing an example that includes 3D drawing, please start the program as follows.

```sh
$ cd examples/basic
$ python visualization.py
Load a ply point cloud, print it, and render it
MESA: warning: Driver does not support the 0xa7a0 PCI ID.
libGL error: failed to create dri screen
libGL error: failed to load driver: iris
MESA: warning: Driver does not support the 0xa7a0 PCI ID.
libGL error: failed to create dri screen
libGL error: failed to load driver: iris
Error: unknown error	phong_shader.cu:330
```

```sh
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia python visualization.py
```


![speedup](https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/speedup.png)

### Visual odometry with intel realsense D435

![vo](https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/vo_gpu.gif)

### Occupancy grid with intel realsense D435

![og](https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/og_gpu.gif)

### Kinect fusion with intel realsense L515

![kf](https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/kinfu.gif)

### Stereo matching

![sm](https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/stereo.png)

### Fast Global Registration

![fgr](https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/fgr.png)

### Point cloud from laser scan

![fgr](https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/laserscan.gif)

### Collision detection for 2 voxel grids

![col](https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/collision_voxels.gif)

### Drone Path planning

![dp](https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/drone_pathplanning.gif)

### Visual odometry with ROS + D435

This demo works in the following environment.
* ROS melodic
* Python2.7

```
# Launch roscore and rviz in the other terminals.
cd examples/python/ros
python realsense_rgbd_odometry_node.py
```

![vo](https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/ros_vo.gif)

## Visualization

| Point Cloud | Triangle Mesh | Kinematics |
|-------------|---------------|------------|
| <img src="https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/pointcloud.png" width="640"> |  <img src="https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/trianglemesh.png" width="640"> | <img src="https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/kinematics.png" width="640"> |

| Voxel Grid | Occupancy Grid | Distance Transform |
|------------|----------------|--------------------|
|  <img src="https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/voxelgrid.png" width="640"> | <img src="https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/occupancygrid.png" width="640"> | <img src="https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/distancetransform.png" width="640"> |

| Graph | Image |
|-------|-------|
| <img src="https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/graph.png" width="640"> | <img src="https://raw.githubusercontent.com/alexmelekhin/cupoch/main/docs/_static/image.png" width="640"> |

## References

* CUDA repository forked from Open3D, https://github.com/theNded/Open3D
* GPU computing in Robotics, https://github.com/JanuszBedkowski/gpu_computing_in_robotics
* Voxel collision comupation for robotics, https://github.com/fzi-forschungszentrum-informatik/gpu-voxels

## Citing

```
@misc{cupoch,
   author = {Kenta Tanaka},
   year = {2020},
   note = {https://github.com/neka-nat/cupoch},
   title = {cupoch -- Robotics with GPU computing}
}
```
