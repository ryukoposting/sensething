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
        r = read
        @val = if r.nil?
                 nil
               else
                 Float(r)
               end
      end
    end

    module IntegralNumber
      def fetch
        r = read
        @val = if r.nil?
                 nil
               else
                 Integer(r)
               end
      end
    end
  end
end
