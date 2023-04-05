# Copyright 2020 DeepMind Technologies Limited. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""A utility to serialize nodes and raise an error if they are not serializable.


For the launch configurations that use this feature, one can test them using:

```
from launchpad.launch import serialization_test

class SerializationTest(serialization_test.ErrorOnSerializationMixin):

  @property
  def _launch(self):
    return launch.launch
```
"""
import copyreg
import functools

from absl import flags

import cloudpickle

from launchpad import flags as lp_flags  

FLAGS = flags.FLAGS


@functools.lru_cache(maxsize=1)
def enable_lru_cache_pickling_once():
  """Enables pickling for functools.lru_cache."""
  lru_cache_type = type(functools.lru_cache()(lambda: None))

  def new_lru_cache(func, cache_kwargs):
    return functools.lru_cache(**cache_kwargs)(func)

  def _pickle_lru_cache(obj):
    params = {}
    if hasattr(obj, "cache_parameters"):
      params = obj.cache_parameters()
    return new_lru_cache, (obj.__wrapped__, params)

  copyreg.pickle(lru_cache_type, _pickle_lru_cache)


def _cloudpickle_dump_with_user_friendly_error(functions,
                                               description: str,
                                               file=None):
  """Serializes functions, and throws user-friendly error upon failure."""
  try:
    if file:
      return cloudpickle.dump(functions, file)
    else:
      return cloudpickle.dumps(functions)
  except Exception as e:
    # When using `pdb`, we want to be able to go up the stack that goes into
    # the serialization error, not through the call-stack up to functions like
    # `check_nodes_are_serializable`. Thus, we need to propagate the traceback.
    raise RuntimeError(
        str(e.__class__.__name__) + ": " + str(e) + "\n"
        f"The nodes associated to {description} were "
        "not serializable using cloudpickle. Make them picklable, or pass "
        "`serialize_py_nodes=False` to `lp.launch` if you want to disable this "
        "check, for example when you want to use FLAGS, mocks, threading.Event "
        "etc, in your node definition."
    ).with_traceback(e.__traceback__) from e


def check_nodes_are_serializable(label, nodes):
  """Raises an exception if some `PyNode` objects are not serializable."""
  enable_lru_cache_pickling_once()
  # We only try to serialize `PyNode` objects (as they are the only nodes for
  # which the default implementation of `to_executables` will do serialization
  # of `node.function`).
  functions = [node.function for node in nodes if hasattr(node, "function")]
  _cloudpickle_dump_with_user_friendly_error(functions,
                                             f"{label} ({type(nodes[0])}")


def serialize_functions(data_file_path: str, description: str, functions):
  """Serializes into a file at path `data_file_path` for PyNode functions.

  Args:
    data_file_path: The path of the (local) file to write to.
    description: Describes the functions, e,g., the label of the group they
      belongs to. This is propagated to enrich the error message.
    functions: PyNode functions as a list or list-like object.
  """
  enable_lru_cache_pickling_once()
  with open(data_file_path, "wb") as f:
    _cloudpickle_dump_with_user_friendly_error(functions, description, f)
