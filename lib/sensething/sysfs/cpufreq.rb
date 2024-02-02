# frozen_string_literal: true

require 'pathname'
require_relative 'attribute'
require_relative 'device'

module Sysfs
  class CpufreqAttribute < Attribute
    module Megahertz
      def fetch
        # hwmon measures in kilohertz
        @val = Float(read) / 1000.0
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
    def self.parse_attr_by_name(name, path)
      case name
      when 'scaling_cur_freq'
        FrequencyValue.new(path)
      when 'scaling_min_freq'
        FrequencyMin.new(path)
      when 'scaling_max_freq'
        FrequencyMax.new(path)
      when 'scaling_governor'
        Governor.new(path)
      end
    end

    def create_sensor(attrs)
      CpuFreqSensor.new(self, attrs)
    end

    protected

    def discover_attributes
      attrs = []
      @path.each_child do |pn|
        if (attr = self.class.parse_attr_by_name(pn.basename.to_s, pn))
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
        when FrequencyMin
          @min_attr = a
        when FrequencyMax
          @max_attr = a
        when FrequencyValue
          @value_attr = a
        when Governor
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
      result << "governor: #{governor_attr.path}" if governor_attr
      result << "min: #{min_attr.path}" if min_attr
      result << "max: #{max_attr.path}" if max_attr
      result.join("\n")
    end
  end

  class FrequencyValue < CpufreqAttribute
    include Megahertz
  end

  class FrequencyMin < CpufreqAttribute
    include Megahertz
  end

  class FrequencyMax < CpufreqAttribute
    include Megahertz
  end

  class Governor < CpufreqAttribute
    def fetch
      @val = read.strip
    end
  end
end
