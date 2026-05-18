from .cupoch import *  # noqa: F401,F403
from importlib.metadata import version as _version

initialize_allocator()
__version__ = _version("cupoch")
