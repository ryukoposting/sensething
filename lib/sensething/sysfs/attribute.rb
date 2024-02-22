# frozen_string_literal: true

require_relative '../common/attribute'
require 'pathname'

module SenseThing
  module Sysfs
    class Attribute < SenseThing::Attribute
      attr_reader :path

      def initialize(path)
        super()
        @path = path
        @path = Pathname.new(@path) unless @path.instance_of? Pathname
        @path = @path.realpath
        return if @path.file?

        raise "Not a file: #{@path.inspect}"
      end

      def read
        File.read(path)
      rescue Errno::ENODATA, Errno::ENXIO
        nil
      end

      def same_sensor?(_other)
        raise 'TODO'
      end
    end
  end
end
