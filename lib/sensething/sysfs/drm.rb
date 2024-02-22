# frozen_string_literal: true

require 'pathname'
require_relative 'attribute'
require_relative 'device'

module SenseThing
  module Sysfs
    class DrmAttribute < Attribute
      module Megahertz
        include SenseThing::Attribute::DecimalNumber
        def unit
          'MHz'
        end

        def same_sensor?(_other)
          true # for drm, each 'device' represents a single sensor
        end
      end
    end

    class Drm < Device
      def self.parse_attr_by_name(path)
        path = Pathname.new(path.to_s) unless path.is_a? Pathname
        name = path.basename.to_s
        case name
        when 'gt_cur_freq_mhz'
          DrmFrequencyValue.new(path)
        when 'gt_min_freq_mhz'
          DrmFrequencyMin.new(path)
        when 'gt_max_freq_mhz'
          DrmFrequencyMax.new(path)
        when 'gt_boost_freq_mhz'
          DrmFrequencyBoost.new(path)
        end
      end

      def create_sensor(attrs)
        DrmSensor.new(self, attrs)
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
        @name = path.basename
      end
    end

    class DrmSensor < SenseThing::Sensor
      attr_reader :device, :min_attr, :max_attr, :value_attr, :boost_attr

      def initialize(device, attrs)
        super()
        @device = device
        attrs.each do |a|
          case a
          when DrmFrequencyValue
            @value_attr = a
          when DrmFrequencyMin
            @min_attr = a
          when DrmFrequencyMax
            @max_attr = a
          when DrmFrequencyBoost
            @boost_attr = a
          end
        end
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

      def unit
        value_attr&.unit
      end

      def name
        "#{device.name}/frequency"
      end

      def summary
        "Graphics Frequency (drm/#{device.path.basename})"
      end

      def detail
        result = []
        result << "value: #{value_attr.path}" if value_attr
        result << "min: #{min_attr.path}" if min_attr
        result << "max: #{max_attr.path}" if max_attr
        result << "boost: #{boost_attr.path}" if boost_attr
        result.join("\n")
      end
    end

    class DrmFrequencyValue < DrmAttribute
      include Megahertz
    end

    class DrmFrequencyMin < DrmAttribute
      include Megahertz
    end

    class DrmFrequencyMax < DrmAttribute
      include Megahertz
    end

    class DrmFrequencyBoost < DrmAttribute
      include Megahertz
    end
  end
end
