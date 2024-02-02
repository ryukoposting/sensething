# frozen_string_literal: true

require_relative 'sensething/sysfs'
require_relative 'sensething/nvidia'
require_relative 'sensething/cli'
require_relative 'sensething/timestamp'

module SenseThing
  def self.discover_devices(&block)
    Dir.glob('/sys/class/hwmon/*').each do |path|
      dev = begin
        Sysfs::Hwmon.new(path)
      rescue StandardError => e
        warn "Tried to access a device at #{path.inspect}, but threw an exception: #{e}"
        warn e.backtrace
      end

      yield dev
    end

    Dir.glob('/sys/devices/system/cpu/*/cpufreq') do |path|
      dev = begin
        Sysfs::Cpufreq.new(path)
      rescue StandardError => e
        warn "Tried to access a device at #{path.inspect}, but threw an exception: #{e}"
        warn e.backtrace
      end

      yield dev
    end

    NvidiaSmi::SmiDevice.enumerate_gpus(&block)
  end
end
