# frozen_string_literal: true

require_relative 'sensething/sysfs'
require_relative 'sensething/nvidia'
require_relative 'sensething/cli'
require_relative 'sensething/timestamp'
require 'pathname'

module SenseThing
  def self.discover_devices(&block)
    discover_hwmon_devices(&block)
    discover_cpufreq_devices(&block)
    NvidiaSmi::SmiDevice.enumerate_gpus(&block)
    discover_drm_devices(&block)
  end

  def self.discover_hwmon_devices
    Dir.glob('/sys/class/hwmon/*').each do |path|
      dev = begin
        Sysfs::Hwmon.new(path)
      rescue StandardError => e
        warn "Tried to access a device at #{path.inspect}, but threw an exception: #{e}"
        warn e.backtrace
      end

      yield dev
    end
  end

  def self.discover_cpufreq_devices
    Dir.glob('/sys/devices/system/cpu/*/cpufreq') do |path|
      dev = begin
        Sysfs::Cpufreq.new(path)
      rescue StandardError => e
        warn "Tried to access a device at #{path.inspect}, but threw an exception: #{e}"
        warn e.backtrace
      end

      yield dev
    end
  end

  def self.discover_drm_devices
    Dir.glob('/sys/class/drm/*').each do |path|
      path = Pathname.new(path).realpath
      next unless path.join('gt').directory?

      dev = begin
        Sysfs::Drm.new(path)
      rescue StandardError => e
        warn "Tried to access a device at #{path.inspect}, but threw an exception: #{e}"
        warn e.backtrace
      end

      yield dev
    end
  end
end
