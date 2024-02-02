# frozen_string_literal: true

module SenseThing
  class Sensor
    def name
      raise 'TODO'
    end

    def fetch
      raise 'TODO'
    end

    def value(fetch: false)
      @value = self.fetch if fetch
      @value
    end

    def minimum; end
    def maximum; end

    def limits
      [minimum, maximum]
    end

    def summary
      raise 'TODO'
    end

    def detail
      raise 'TODO'
    end

    def unit
      raise 'TODO'
    end
  end
end
