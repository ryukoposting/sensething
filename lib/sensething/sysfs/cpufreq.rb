# frozen_string_literal: true

require 'pathname'
require_relative 'attribute'
require_relative 'device'

module Sysfs
  class CpufreqAttribute < Attribute
    module Megahertz
      def fetch
        # hwmon measures in kilohertz
        r = read
        @val = if r.nil?
                 nil
               else
                 Float(r) / 1000.0
               end
      end

      def unit
        'MHz'
      end

      def same_sensor?(_other)
        true # for cpufreq, each 'device' represents a single sensor
      end
    end
  end

  class Cpufreq < Device
    def self.parse_attr_by_name(path)
      path = Pathname.new(path.to_s) unless path.is_a? Pathname
      name = path.basename.to_s
      case name
      when 'scaling_cur_freq'
        CpuFrequencyValue.new(path)
      when 'scaling_min_freq'
        CpuFrequencyMin.new(path)
      when 'scaling_max_freq'
        CpuFrequencyMax.new(path)
      when 'scaling_governor'
        CpuGovernor.new(path)
      end
    end

    def create_sensor(attrs)
      CpuFreqSensor.new(self, attrs)
    end

    protected

    def discover_attributes
      attrs = []
      @path.each_child do |pn|
        if (attr = self.class.parse_attr_by_name(pn))
          attrs << attr
        end
      end
      @attrs = attrs
    end

    def discover_name
      related_cpus = File.read(@path.join('related_cpus')).strip
      @name = "cpu#{related_cpus.split(' ').join('_')}"
    rescue Errno::ENOENT
      @noname = true
    end
  end

  class CpuFreqSensor < SenseThing::Sensor
    attr_reader :device, :min_attr, :max_attr, :value_attr, :governor_attr

    def initialize(device, attrs)
      super()
      @device = device
      attrs.each do |a|
        case a
        when CpuFrequencyMin
          @min_attr = a
        when CpuFrequencyMax
          @max_attr = a
        when CpuFrequencyValue
          @value_attr = a
        when CpuGovernor
          @governor_attr = a
        end
      end
    end

    def unit
      value_attr&.unit
    end

    def fetch
      value_attr&.fetch
    end

    def value(fetch: false)
      value_attr&.value(fetch: fetch)
    end

    def minimum
      min_attr&.value
    end

    def maximum
      max_attr&.value
    end

    def units
      value_attr&.unit
    end

    def name
      "#{device.name}/frequency"
    end

    def summary
      "CPU Frequency (cpufreq/#{device.path.basename})"
    end

    def detail
      result = []
      result << "value: #{value_attr.path}" if value_attr
      result << "CpuGovernor: #{governor_attr.path}" if governor_attr
      result << "min: #{min_attr.path}" if min_attr
      result << "max: #{max_attr.path}" if max_attr
      result.join("\n")
    end
  end

  class CpuFrequencyValue < CpufreqAttribute
    include Megahertz
  end

  class CpuFrequencyMin < CpufreqAttribute
    include Megahertz
  end

  class CpuFrequencyMax < CpufreqAttribute
    include Megahertz
  end

  class CpuGovernor < CpufreqAttribute
    def fetch
      @val = read.strip
    end
  end
end
