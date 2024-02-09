# frozen_string_literal: true

require 'pathname'
require_relative '../sensor'
require_relative 'attribute'
require_relative 'device'

module Sysfs
  class HwmonAttribute < Attribute
    attr_reader :chan_num

    def initialize(path, chan_num)
      super(path)
      @chan_num = Integer(chan_num)
    end

    def type
      raise 'TODO'
    end

    def same_sensor?(other)
      chan_num == other.chan_num && type == other.type
    end

    module Millivolts
      include Attribute::DecimalNumber
      def unit
        'mV'
      end

      def type
        :voltage
      end
    end

    module Milliamps
      include Attribute::DecimalNumber
      def unit
        'mA'
      end

      def type
        :current
      end
    end

    module Rpm
      include Attribute::DecimalNumber
      def unit
        'RPM'
      end

      def type
        :fan
      end
    end

    module Celsius
      def fetch
        # hwmon measures in millidegrees
        @val = Float(read) / 1000.0
      end

      def unit
        '°C'
      end

      def type
        :temperature
      end
    end
  end

  class Hwmon < Device
    def self.parse_attr_by_name(path)
      path = Pathname.new(path.to_s) unless path.is_a? Pathname
      name = path.basename.to_s
      if name.start_with? 'in'
        chan_num, type = parse_attr_num_text(name[2..])
        parse_in_attr(chan_num, type, path)
      elsif name.start_with? 'curr'
        chan_num, type = parse_attr_num_text(name[4..])
        parse_curr_attr(chan_num, type, path)
      elsif name.start_with? 'fan'
        chan_num, type = parse_attr_num_text(name[3..])
        parse_fan_attr(chan_num, type, path)
      elsif name.start_with? 'pwm'
        chan_num, type = parse_attr_num_text(name[3..])
        parse_pwm_attr(chan_num, type, path)
      elsif name.start_with? 'temp'
        chan_num, type = parse_attr_num_text(name[4..])
        parse_temperature_attr(chan_num, type, path)
      end
    end

    def create_sensor(attrs)
      case attrs[0].type
      when :voltage
        HwmonVoltageSensor.new(self, attrs[0].type, attrs[0].chan_num, attrs)
      when :current
        HwmonCurrentSensor.new(self, attrs[0].type, attrs[0].chan_num, attrs)
      when :temperature
        HwmonTemperatureSensor.new(self, attrs[0].type, attrs[0].chan_num, attrs)
      when :fan
        HwmonFanSensor.new(self, attrs[0].type, attrs[0].chan_num, attrs)
      when :pwm
        HwmonPwmSensor.new(self, attrs[0].type, attrs[0].chan_num, attrs)
      end
    end

    protected

    def discover_attributes
      attrs = []
      @path.each_child do |pn|
        if (attr = self.class.parse_attr_by_name(pn))
          attrs << attr
        end
      end
      @attrs = attrs.sort_by { |a| [a.chan_num, a.path.basename.to_s] }
    end

    def discover_name
      @name = File.read(@path.join('name')).strip
    rescue Errno::ENOENT
      @noname = true
    end

    class << self
      def parse_in_attr(chan_num, type, path)
        case type
        when 'min'
          VoltageMin.new(path, chan_num)
        when 'lcrit'
          VoltageCriticalMin.new(path, chan_num)
        when 'max'
          VoltageMax.new(path, chan_num)
        when 'crit'
          VoltageCriticalMax.new(path, chan_num)
        when 'input'
          VoltageValue.new(path, chan_num)
        when 'average'
          VoltageAverage.new(path, chan_num)
        when 'lowest'
          VoltageLowest.new(path, chan_num)
        when 'highest'
          VoltageHighest.new(path, chan_num)
        when 'label'
          VoltageLabel.new(path, chan_num)
        end
      end

      def parse_curr_attr(chan_num, type, path)
        case type
        when 'min'
          CurrentMin.new(path, chan_num)
        when 'lcrit'
          CurrentCriticalMin.new(path, chan_num)
        when 'max'
          CurrentMax.new(path, chan_num)
        when 'crit'
          CurrentCriticalMax.new(path, chan_num)
        when 'input'
          CurrentValue.new(path, chan_num)
        when 'average'
          CurrentAverage.new(path, chan_num)
        when 'lowest'
          CurrentLowest.new(path, chan_num)
        when 'highest'
          CurrentHighest.new(path, chan_num)
        end
      end

      def parse_fan_attr(chan_num, type, path)
        case type
        when 'min'
          FanMin.new(path, chan_num)
        when 'max'
          FanMax.new(path, chan_num)
        when 'input'
          FanValue.new(path, chan_num)
        when 'div'
          FanDivisor.new(path, chan_num)
        when 'pulses'
          FanPulses.new(path, chan_num)
        when 'target'
          FanTarget.new(path, chan_num)
        when 'label'
          FanLabel.new(path, chan_num)
        when 'enable'
          FanEnabled.new(path, chan_num)
        end
      end

      def parse_pwm_attr(chan_num, type, path)
        case type
        when nil
          PwmValue.new(path, chan_num) if chan_num
        when 'enable'
          PwmEnabled.new(path, chan_num)
        end
      end

      def parse_temperature_attr(chan_num, type, path) # rubocop:disable Metrics/MethodLength,Metrics/CyclomaticComplexity
        case type
        when 'type'
          TemperatureType.new(path, chan_num)
        when 'max'
          TemperatureMax.new(path, chan_num)
        when 'min'
          TemperatureMin.new(path, chan_num)
        when 'max_hyst'
          TemperatureMaxHysteresis.new(path, chan_num)
        when 'min_hyst'
          TemperatureMinHysteresis.new(path, chan_num)
        when 'input'
          TemperatureValue.new(path, chan_num)
        when 'crit'
          TemperatureCriticalMax.new(path, chan_num)
        when 'crit_hyst'
          TemperatureCriticalMaxHysteresis.new(path, chan_num)
        when 'lcrit'
          TemperatureCriticalMin.new(path, chan_num)
        when 'lcrit_hyst'
          TemperatureCriticalMinHysteresis.new(path, chan_num)
        when 'emergency'
          TemperatureEmergency.new(path, chan_num)
        when 'emergency_hyst'
          TemperatureEmergencyHysteresis.new(path, chan_num)
        when 'lowest'
          TemperatureLowest.new(path, chan_num)
        when 'highest'
          TemperatureHighest.new(path, chan_num)
        when 'label'
          TemperatureLabel.new(path, chan_num)
        when 'enable'
          TemperatureEnable.new(path, chan_num)
        end
      end

      def parse_attr_num_text(subname)
        return unless /^([0-9]+)/ =~ subname

        num = $1
        return [num] if num.length == subname.length

        subname = subname[num.length..]

        return unless /^_([a-z_]+)$/ =~ subname

        [num, $1]
      end
    end
  end

  class HwmonSensor < SenseThing::Sensor
    attr_reader :device, :label_attr, :value_attr, :min_attr, :max_attr

    def initialize(device, type, chan_num)
      super()
      @device = device
      @type = type
      @chan_num = chan_num
    end

    def name
      if label_attr
        "#{device.name}/#{label_attr.value}"
      else
        "#{device.name}/#{@type}_#{@chan_num}"
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
  end

  class HwmonVoltageSensor < HwmonSensor
    def initialize(device, type, chan_num, attrs)
      super(device, type, chan_num)
      attrs.each do |a|
        case a
        when VoltageMin
          @min_attr = a
        when VoltageMax
          @max_attr = a
        when VoltageCriticalMin
          @crit_min_attr = a
        when VoltageCriticalMax
          @crit_max_attr = a
        when VoltageValue
          @value_attr = a
        when VoltageLabel
          @label_attr = a
        end
      end
    end

    def summary
      "Voltage Sensor (#{device.path.basename}/in#{@chan_num})"
    end

    def detail
      result = []
      result << "value: #{value_attr.path}" if value_attr
      result << "label: #{label_attr.path}" if label_attr
      result << "min: #{min_attr.path}" if min_attr
      result << "max: #{max_attr.path}" if max_attr
      result << "critical min: #{crit_min_attr.path}" if @crit_min_attr
      result << "critical max: #{crit_max_attr.path}" if @crit_max_attr
      result.join("\n")
    end
  end

  class HwmonCurrentSensor < HwmonSensor
    def initialize(device, type, chan_num, attrs)
      super(device, type, chan_num)
      attrs.each do |a|
        case a
        when CurrentMin
          @min_attr = a
        when CurrentMax
          @max_attr = a
        when CurrentCriticalMin
          @crit_min_attr = a
        when CurrentCriticalMax
          @crit_max_attr = a
        when CurrentValue
          @value_attr = a
        when CurrentLabel
          @label_attr = a
        end
      end
    end

    def summary
      "Current Sensor (#{device.path.basename}/curr#{@chan_num})"
    end

    def detail
      result = []
      result << "value: #{value_attr.path}" if value_attr
      result << "label: #{label_attr.path}" if label_attr
      result << "min: #{min_attr.path}" if min_attr
      result << "max: #{max_attr.path}" if max_attr
      result << "critical min: #{crit_min_attr.path}" if @crit_min_attr
      result << "critical max: #{crit_max_attr.path}" if @crit_max_attr
      result.join("\n")
    end
  end

  class HwmonTemperatureSensor < HwmonSensor
    def initialize(device, type, chan_num, attrs)
      super(device, type, chan_num)
      attrs.each do |a|
        case a
        when TemperatureMin
          @min_attr = a
        when TemperatureMax
          @max_attr = a
        when TemperatureValue
          @value_attr = a
        when TemperatureLabel
          @label_attr = a
        when TemperatureType
          @temp_type_attr = a
        end
      end
    end

    def summary
      "Temperature Sensor (#{device.path.basename}/temp#{@chan_num})"
    end

    def detail
      result = []
      result << "value: #{value_attr.path}" if value_attr
      result << "label: #{label_attr.path}" if label_attr
      result << "min: #{min_attr.path}" if min_attr
      result << "max: #{max_attr.path}" if max_attr
      result << "type: #{@temp_type_attr.path}" if @temp_type_attr
      result.join("\n")
    end
  end

  class HwmonFanSensor < HwmonSensor
    def initialize(device, type, chan_num, attrs)
      super(device, type, chan_num)
      attrs.each do |a|
        case a
        when FanMin
          @min_attr = a
        when FanMax
          @max_attr = a
        when FanValue
          @value_attr = a
        when FanLabel
          @label_attr = a
        end
      end
    end

    def summary
      "Fan (#{device.path.basename}/fan#{@chan_num})"
    end

    def detail
      result = []
      result << "value: #{value_attr.path}" if value_attr
      result << "label: #{label_attr.path}" if label_attr
      result << "min: #{min_attr.path}" if min_attr
      result << "max: #{max_attr.path}" if max_attr
      result.join("\n")
    end
  end

  class HwmonPwmSensor < HwmonSensor
    def initialize(device, type, chan_num, attrs)
      super(device, type, chan_num)
      attrs.each do |a|
        case a
        when PwmValue
          @value_attr = a
        end
      end
    end

    def summary
      "PWM (#{device.path.basename}/pwm#{@chan_num})"
    end

    def detail
      result = []
      result << "value: #{value_attr.path}" if value_attr
      result.join("\n")
    end
  end

  class VoltageMin < HwmonAttribute
    include Millivolts
  end

  class VoltageCriticalMin < HwmonAttribute
    include Millivolts
  end

  class VoltageMax < HwmonAttribute
    include Millivolts
  end

  class VoltageCriticalMax < HwmonAttribute
    include Millivolts
  end

  class VoltageValue < HwmonAttribute
    include Millivolts
  end

  class VoltageAverage < HwmonAttribute
    include Millivolts
  end

  class VoltageLowest < HwmonAttribute
    include Millivolts
  end

  class VoltageHighest < HwmonAttribute
    include Millivolts
  end

  class VoltageLabel < HwmonAttribute
    def fetch
      @val = read.strip.gsub(/\s+/, '_')
    end

    def type
      :voltage
    end
  end

  class CurrentMin < HwmonAttribute
    include Milliamps
  end

  class CurrentCriticalMin < HwmonAttribute
    include Milliamps
  end

  class CurrentMax < HwmonAttribute
    include Milliamps
  end

  class CurrentCriticalMax < HwmonAttribute
    include Milliamps
  end

  class CurrentValue < HwmonAttribute
    include Milliamps
  end

  class CurrentAverage < HwmonAttribute
    include Milliamps
  end

  class CurrentLowest < HwmonAttribute
    include Milliamps
  end

  class CurrentHighest < HwmonAttribute
    include Milliamps
  end

  class FanMin < HwmonAttribute
    include Rpm
  end

  class FanMax < HwmonAttribute
    include Rpm
  end

  class FanValue < HwmonAttribute
    include Rpm
  end

  class FanDivisor < HwmonAttribute
    include IntegralNumber
    def type
      :fan
    end
  end

  class FanPulses < HwmonAttribute
    include IntegralNumber
    def type
      :fan
    end
  end

  class FanTarget < HwmonAttribute
    include Rpm
    def type
      :fan
    end
  end

  class FanLabel < HwmonAttribute
    def fetch
      @val = read.strip
    end

    def type
      :fan
    end
  end

  class FanEnabled < HwmonAttribute
    def fetch
      @val = read.strip != '0'
    end

    def type
      :fan
    end
  end

  class PwmValue < HwmonAttribute
    def fetch
      @val = Float(read) / 255.0
    end

    def type
      :pwm
    end
  end

  class PwmEnabled < HwmonAttribute
    def fetch
      @val = read.strip != '0'
    end

    def type
      :pwm
    end
  end

  class TemperatureType < HwmonAttribute
    CPU_DIODE = 1
    TRANSISTOR_3904 = 2
    THERMAL_DIODE = 3
    THERMISTOR = 4
    AMDSI = 5
    PECI = 6

    @type_vals = {
      '1': CPU_DIODE,
      '2': TRANSISTOR_3904,
      '3': THERMAL_DIODE,
      '4': THERMISTOR,
      '5': AMDSI,
      '6': PECI
    }

    def fetch
      self.class.type_vals[read.strip]
    end

    def type
      :temperature
    end
  end

  class TemperatureMax < HwmonAttribute
    include Celsius
  end

  class TemperatureMin < HwmonAttribute
    include Celsius
  end

  class TemperatureMaxHysteresis < HwmonAttribute
    include Celsius
  end

  class TemperatureMinHysteresis < HwmonAttribute
    include Celsius
  end

  class TemperatureValue < HwmonAttribute
    include Celsius
  end

  class TemperatureCriticalMax < HwmonAttribute
    include Celsius
  end

  class TemperatureCriticalMaxHysteresis < HwmonAttribute
    include Celsius
  end

  class TemperatureCriticalMin < HwmonAttribute
    include Celsius
  end

  class TemperatureCriticalMinHysteresis < HwmonAttribute
    include Celsius
  end

  class TemperatureEmergency < HwmonAttribute
    include Celsius
  end

  class TemperatureEmergencyHysteresis < HwmonAttribute
    include Celsius
  end

  class TemperatureLowest < HwmonAttribute
    include Celsius
  end

  class TemperatureHighest < HwmonAttribute
    include Celsius
  end

  class TemperatureLabel < HwmonAttribute
    def fetch
      @val = read.strip
    end

    def type
      :temperature
    end
  end

  class TemperatureEnable < HwmonAttribute
    def fetch
      @val = read.strip != '0'
    end

    def type
      :temperature
    end
  end
end
