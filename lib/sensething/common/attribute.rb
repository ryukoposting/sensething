# frozen_string_literal: true

module SenseThing
  class Attribute
    def fetch
      @val = read
    end

    def value(fetch: false)
      return @val unless fetch || @val.nil?

      self.fetch
    end

    def unit
      nil
    end

    module DecimalNumber
      def fetch
        @val = Float(read)
      end
    end

    module IntegralNumber
      def fetch
        @val = Integer(read)
      end
    end
  end
end
