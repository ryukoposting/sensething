# frozen_string_literal: true

require_relative '../common/device'

module SenseThing
  module Nvidia
    class Device < SenseThing::Device
      attr_reader :name, :uuid

      def initialize(name, uuid)
        super()
        @name = name
        @uuid = uuid
      end
    end
  end
end
