# frozen_string_literal: true

require 'mkmf'
require 'fiddle'

if have_library('nvidia-ml')
  module Nvidia
    module Ffi
      extend Fiddle::Importer
      dlload 'libnvidia-ml.so'
    end
  end
end

if $nvml_dll
  module Nvidia
    module Ffi
      # The operation was successful.
      NVML_SUCCESS = 0
      # NVML was not first initialized with nvmlInit().
      NVML_ERROR_UNINITIALIZED = 1
      # A supplied argument is invalid.
      NVML_ERROR_INVALID_ARGUMENT = 2
      # The requested operation is not available on target device.
      NVML_ERROR_NOT_SUPPORTED = 3
      # The current user does not have permission for operation.
      NVML_ERROR_NO_PERMISSION = 4
      # Deprecated: Multiple initializations are now allowed through ref counting.
      NVML_ERROR_ALREADY_INITIALIZED = 5
      # A query to find an object was unsuccessful.
      NVML_ERROR_NOT_FOUND = 6
      # An input argument is not large enough.
      NVML_ERROR_INSUFFICIENT_SIZE = 7
      # A device's external power cables are not properly attached.
      NVML_ERROR_INSUFFICIENT_POWER = 8
      # NVIDIA driver is not loaded.
      NVML_ERROR_DRIVER_NOT_LOADED = 9
      # User provided timeout passed.
      NVML_ERROR_TIMEOUT = 10
      # NVIDIA Kernel detected an interrupt issue with a GPU.
      NVML_ERROR_IRQ_ISSUE = 11
      # NVML Shared Library couldn't be found or loaded.
      NVML_ERROR_LIBRARY_NOT_FOUND = 12
      # Local version of NVML doesn't implement this function.
      NVML_ERROR_FUNCTION_NOT_FOUND = 13
      # infoROM is corrupted
      NVML_ERROR_CORRUPTED_INFOROM = 14
      # The GPU has fallen off the bus or has otherwise become inaccessible.
      NVML_ERROR_GPU_IS_LOST = 15
      # The GPU requires a reset before it can be used again.
      NVML_ERROR_RESET_REQUIRED = 16
      # The GPU control device has been blocked by the operating system/cgroups.
      NVML_ERROR_OPERATING_SYSTEM = 17
      # RM detects a driver/library version mismatch.
      NVML_ERROR_LIB_RM_VERSION_MISMATCH = 18
      # An operation cannot be performed because the GPU is currently in use.
      NVML_ERROR_IN_USE = 19
      # Insufficient memory.
      NVML_ERROR_MEMORY = 20
      # No data.
      NVML_ERROR_NO_DATA = 21
      # The requested vgpu operation is not available on target device, becasue ECC is enabled.
      NVML_ERROR_VGPU_ECC_NOT_SUPPORTED = 22
      # Ran out of critical resources, other than memory.
      NVML_ERROR_INSUFFICIENT_RESOURCES = 23
      # Ran out of critical resources, other than memory.
      NVML_ERROR_FREQ_NOT_SUPPORTED = 24
      # The provided version is invalid/unsupported.
      NVML_ERROR_ARGUMENT_VERSION_MISMATCH = 25
      # The requested functionality has been deprecated.
      NVML_ERROR_DEPRECATED = 26
      # The system is not ready for the request.
      NVML_ERROR_NOT_READY = 27
      # An internal driver error occurred.
      NVML_ERROR_UNKNOWN = 999

      NVML_SYSTEM_NVML_VERSION_BUFFER_SIZE = 80
      NVML_DEVICE_NAME_V2_BUFFER_SIZE = 96
      NVML_DEVICE_SERIAL_BUFFER_SIZE = 30
      NVML_DEVICE_UUID_V2_BUFFER_SIZE = 96

      Fiddle.struct

      INIT_WITH_FLAGS = Fiddle::Function.new(
        $nvml_dll['nvmlInitWithFlags'],
        [Fiddle::TYPE_UINT],
        Fiddle::TYPE_INT
      )

      SHUT_DOWN = Fiddle::Function.new(
        $nvml_dll['nvmlShutdown'],
        [],
        Fiddle::TYPE_INT
      )

      SYSTEM_GET_NVML_VERSION = Fiddle::Function.new(
        $nvml_dll['nvmlSystemGetNVMLVersion'],
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT],
        Fiddle::TYPE_INT
      )

      ERROR_STRING = Fiddle::Function.new(
        $nvml_dll['nvmlErrorString'],
        [Fiddle::TYPE_INT],
        Fiddle::TYPE_VOIDP
      )

      GET_DEVICE_COUNT_V2 = Fiddle::Function.new(
        $nvml_dll['nvmlDeviceGetCount_v2'],
        [Fiddle::TYPE_UINTPTR_T],
        Fiddle::TYPE_INT
      )

      GET_DEVICE_HANDLE_BY_INDEX_V2 = Fiddle::Function.new(
        $nvml_dll['nvmlDeviceGetHandleByIndex_v2'],
        [Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_INT
      )
    end
  end

  if Nvidia::Ffi::INIT_WITH_FLAGS.call(1) == Nvidia::Ffi::NVML_SUCCESS
    at_exit do
      Nvidia::Ffi::SHUT_DOWN.call
    end
  else
    $nvml_dll = nil
  end
end

module Nvidia
  def self.has_nvml?
    !$nvml_dll.nil?
  end
end
