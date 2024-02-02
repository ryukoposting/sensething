# frozen_string_literal: true

require_relative '../common/device'
require 'pathname'

module Sysfs
  class Device < SenseThing::Device
    attr_reader :path

    def initialize(path)
      super()
      @path = path
      @path = Pathname.new(@path) unless @path.instance_of? Pathname
      @path = @path.realpath
      raise "Not a directory: #{@path.inspect}" unless @path.directory?

      @attrs = nil
      @name = nil
      @noname = false
    end

    def name
      return @name if @name || @noname

      discover_name
    end

    def each_attribute(&block)
      return @attrs if @attrs

      discover_attributes.each(&block)
    end

    def each_sensor
      remain = Array(each_attribute)
      until remain.empty?
        a0 = remain.shift
        sens_attrs, remain = remain.partition { |a| a0.same_sensor? a }
        sens_attrs << a0
        yield create_sensor(sens_attrs)
      end
    end

    def discover_attributes
      raise 'TODO'
    end

    def create_sensor(_attrs)
      raise 'TODO'
    end
  end
end
