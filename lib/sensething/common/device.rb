# frozen_string_literal: true

module SenseThing
  class Device
    def each_attribute(&block)
      return @attrs if @attrs

      discover_attributes.each(&block)
    end

    def each_sensor
      raise 'TODO'
    end

    def name
      raise 'TODO'
    end
  end
end
