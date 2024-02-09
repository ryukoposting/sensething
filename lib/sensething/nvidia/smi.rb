# frozen_string_literal: true

require_relative 'device'
require_relative 'attribute'
require 'open3'
require 'csv'

module NvidiaSmi
  class SmiAttribute < Nvidia::Attribute
    attr_accessor :type

    def initialize(key, type, fetch_fn)
      super()
      @key = key.strip
      @type = type
      @fetch_fn = fetch_fn
    end

    def read
      @fetch_fn.call[@key][0]
    end

    module Celsius
      def unit
        '°C'
      end
    end

    module Megahertz
      def fetch
        raw = read
        raise "Invalid nvidia-smi frequency string: #{raw.inspect}" unless /([0-9.]+) +MHz/ =~ raw

        @val = Float($1)
      end

      def unit
        'MHz'
      end
    end

    module Watts
      def fetch
        raw = read
        raise "Invalid nvidia-smi power string: #{raw.inspect}" unless /([0-9.]+) +W/ =~ raw

        @val = Float($1)
      end

      def unit
        'W'
      end
    end

    module Percentage
      def fetch
        raw = read
        raise "Invalid nvidia-smi percentage string: #{raw.inspect}" unless /([0-9.]+) +%/ =~ raw

        @val = Float($1) / 100.0
      end
    end
  end

  class SmiDevice < Nvidia::Device
    attr_reader :index

    def initialize(name, uuid, index)
      super(name, uuid)
      @index = Integer(index)
    end

    def self.enumerate_gpus
      Open3.popen3('nvidia-smi', '-L') do |i, o, _e, _t|
        i.close
        o.read.each_line do |line|
          line.strip!
          if /^GPU ([0-9]+): ([a-zA-Z0-9\- ]+) \(UUID: ([a-zA-Z0-9-]+)\)/ =~ line
            yield SmiDevice.new($2, $3, $1)
          end
        end
      end
    end

    def each_sensor # rubocop:disable Metrics/CyclomaticComplexity
      remain = Array(each_attribute)
      until remain.empty?
        a0 = remain.shift
        sens_attrs, remain = remain.partition { |a| a0.type == a.type }
        sens_attrs << a0

        case a0.type
        when :temperature
          yield NvidiaSmiTemperatureSensor.new(self, sens_attrs)
        when :shader_clock
          yield NvidiaSmiShaderFrequencySensor.new(self, sens_attrs)
        when :mem_clock
          yield NvidiaSmiMemoryFrequencySensor.new(self, sens_attrs)
        when :video_clock
          yield NvidiaSmiVideoFrequencySensor.new(self, sens_attrs)
        when :pcie_gen
          yield NvidiaSmiPcieLinkGenSensor.new(self, sens_attrs)
        when :pcie_width
          yield NvidiaSmiPcieLinkWidthSensor.new(self, sens_attrs)
        when :power
          yield NvidiaSmiPowerSensor.new(self, sens_attrs)
        when :fan
          yield NvidiaSmiFanSensor.new(self, sens_attrs)
        end
      end
    end

    private

    def query_smi
      Open3.popen3('nvidia-smi', "--id=#{@uuid}", "--query-gpu=#{@attr_keys.join(',')}",
                   '--format=csv') do |i, o, _e, t|
        i.close
        return CSV.parse(o.read.strip, headers: true, strip: true) if t.value.success?
      end
      nil
    end

    def update_cached_smi_response
      now = DateTime.now
      return @cached_smi_response unless @last_update.nil? || (now - @last_update >= Rational(1, 86_401))

      @last_update = now
      @cached_smi_response = query_smi
    end

    protected

    def discover_attributes # rubocop:disable Metrics/MethodLength
      attrs = []
      @attr_keys = []
      fetch_fn = -> { update_cached_smi_response }
      # Probe attributes individually to figure out which ones are available
      discover_attribute('temperature.gpu') do |k|
        attrs << TemperatureValue.new('temperature.gpu', :temperature, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('clocks.current.graphics') do |k|
        attrs << ShaderFrequencyValue.new('clocks.current.graphics [MHz]', :shader_clock, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('clocks.max.graphics') do |k|
        attrs << ShaderFrequencyMax.new('clocks.max.graphics [MHz]', :shader_clock, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('clocks.current.memory') do |k|
        attrs << MemoryFrequencyValue.new('clocks.current.memory [MHz]', :mem_clock, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('clocks.max.memory') do |k|
        attrs << MemoryFrequencyMax.new('clocks.max.memory [MHz]', :mem_clock, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('clocks.current.video') do |k|
        attrs << VideoFrequencyValue.new('clocks.current.video [MHz]', :video_clock, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('clocks.max.video') do |k|
        attrs << VideoFrequencyMax.new('clocks.max.video [MHz]', :video_clock, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('pcie.link.gen.gpucurrent') do |k|
        attrs << PcieLinkGenValue.new('pcie.link.gen.gpucurrent', :pcie_gen, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('pcie.link.gen.max') do |k|
        attrs << PcieLinkGenMax.new('pcie.link.gen.max', :pcie_gen, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('pcie.link.gen.gpumax') do |k|
        attrs << PcieLinkGenSupportedByGpu.new('pcie.link.gen.gpumax', :pcie_gen, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('pcie.link.width.current') do |k|
        attrs << PcieLinkWidthValue.new('pcie.link.width.current', :pcie_width, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('pcie.link.width.max') do |k|
        attrs << PcieLinkWidthMax.new('pcie.link.width.max', :pcie_width, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('power.draw') do |k|
        attrs << PowerValue.new('power.draw [W]', :power, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('power.limit') do |k|
        attrs << PowerMax.new('power.limit [W]', :power, fetch_fn)
        @attr_keys << k
      end
      discover_attribute('fan.speed') do |k|
        attrs << FanSpeedValue.new('fan.speed [%]', :fan, fetch_fn)
        @attr_keys << k
      end
      @attrs = attrs
    end

    private

    def discover_attribute(key)
      Open3.popen3('nvidia-smi', "--id=#{uuid}", "--query-gpu=#{key}", '--format=csv,noheader') do |i, _o, _e, t|
        i.close
        yield key if t.value.success?
      end
    end
  end

  class SmiSensor < SenseThing::Sensor
    attr_reader :device, :value_attr, :min_attr, :max_attr

    def initialize(device)
      super()
      @device = device
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

  class NvidiaSmiTemperatureSensor < SmiSensor
    def initialize(device, attrs)
      super(device)
      attrs.each do |a|
        case a
        when TemperatureValue
          @value_attr = a
        end
      end
    end

    def name
      "nvidia#{device.index}/temperature"
    end

    def summary
      "Temperature Sensor (nvidia#{device.index})"
    end

    def detail
      result = []
      result << "gpu: #{device.name}"
      result << "gpuid: #{device.uuid}"
    end
  end

  class NvidiaSmiShaderFrequencySensor < SmiSensor
    def initialize(device, attrs)
      super(device)
      attrs.each do |a|
        case a
        when ShaderFrequencyValue
          @value_attr = a
        when ShaderFrequencyMax
          @max_attr = a
        end
      end
    end

    def name
      "nvidia#{device.index}/shader_frequency"
    end

    def summary
      "Shader Frequency (nvidia#{device.index})"
    end
  end

  class NvidiaSmiMemoryFrequencySensor < SmiSensor
    def initialize(device, attrs)
      super(device)
      attrs.each do |a|
        case a
        when MemoryFrequencyValue
          @value_attr = a
        when MemoryFrequencyMax
          @max_attr = a
        end
      end
    end

    def name
      "nvidia#{device.index}/mem_frequency"
    end

    def summary
      "Memory Frequency (nvidia#{device.index})"
    end
  end

  class NvidiaSmiVideoFrequencySensor < SmiSensor
    def initialize(device, attrs)
      super(device)
      attrs.each do |a|
        case a
        when VideoFrequencyValue
          @value_attr = a
        when VideoFrequencyMax
          @max_attr = a
        end
      end
    end

    def name
      "nvidia#{device.index}/video_frequency"
    end

    def summary
      "Video Frequency (nvidia#{device.index})"
    end
  end

  class NvidiaSmiPcieLinkGenSensor < SmiSensor
    def initialize(device, attrs)
      super(device)
      attrs.each do |a|
        case a
        when PcieLinkGenValue
          @value_attr = a
        when PcieLinkGenMax
          @max_attr = a
        end
      end
    end

    def name
      "nvidia#{device.index}/pcie_gen"
    end

    def summary
      "PCIe Link Generation (nvidia#{device.index})"
    end
  end

  class NvidiaSmiPcieLinkWidthSensor < SmiSensor
    def initialize(device, attrs)
      super(device)
      attrs.each do |a|
        case a
        when PcieLinkWidthValue
          @value_attr = a
        when PcieLinkWidthMax
          @max_attr = a
        end
      end
    end

    def name
      "nvidia#{device.index}/pcie_width"
    end

    def summary
      "PCIe Link Width (nvidia#{device.index})"
    end
  end

  class NvidiaSmiPowerSensor < SmiSensor
    def initialize(device, attrs)
      super(device)
      attrs.each do |a|
        case a
        when PowerValue
          @value_attr = a
        when PowerMax
          @max_attr = a
        end
      end
    end

    def name
      "nvidia#{device.index}/power"
    end

    def summary
      "Power Sensor (nvidia#{device.index})"
    end
  end

  class NvidiaSmiFanSensor < SmiSensor
    def initialize(device, attrs)
      super(device)
      attrs.each do |a|
        case a
        when FanSpeedValue
          @value_attr = a
        end
      end
    end

    def name
      "nvidia#{device.index}/fan"
    end

    def summary
      "Fan (nvidia#{device.index})"
    end
  end

  class TemperatureValue < SmiAttribute
    include Celsius
  end

  class ShaderFrequencyValue < SmiAttribute
    include Megahertz
  end

  class ShaderFrequencyMax < SmiAttribute
    include Megahertz
  end

  class MemoryFrequencyValue < SmiAttribute
    include Megahertz
  end

  class MemoryFrequencyMax < SmiAttribute
    include Megahertz
  end

  class VideoFrequencyValue < SmiAttribute
    include Megahertz
  end

  class VideoFrequencyMax < SmiAttribute
    include Megahertz
  end

  class PcieLinkGenValue < SmiAttribute
    include Nvidia::Attribute::IntegralNumber
  end

  class PcieLinkGenMax < SmiAttribute
    include Nvidia::Attribute::IntegralNumber
  end

  class PcieLinkGenSupportedByGpu < SmiAttribute
    include Nvidia::Attribute::IntegralNumber
  end

  class PcieLinkWidthValue < SmiAttribute
    include Nvidia::Attribute::IntegralNumber
  end

  class PcieLinkWidthMax < SmiAttribute
    include Nvidia::Attribute::IntegralNumber
  end

  class PowerValue < SmiAttribute
    include Watts
  end

  class PowerMax < SmiAttribute
    include Watts
  end

  class FanSpeedValue < SmiAttribute
    include Percentage
  end
end
