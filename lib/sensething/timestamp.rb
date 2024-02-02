# frozen_string_literal: true

module SenseThing
  class Timer
    attr_reader :offset

    def initialize
      set_offset!
      @drift_adjust = 0
    end

    def set_offset!
      @offset = instant
    end

    def instant
      Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    end

    #
    # Offset and drift-adjusted sleep function. This allows for precisely-timed periodic tasks.
    # This is extremely important for keeping precise logging intervals. nvidia-smi in particular can be quite
    # slow, so a dumb sleep function would accumulate error as a result of that slowness.
    #
    def sleep(seconds)
      elapsed = instant - @offset
      elapsed_seconds = Rational(elapsed, 1_000_000_000)
      interval = Float(seconds - elapsed_seconds + @drift_adjust)
      return if interval <= 0

      Kernel.sleep(interval)
      after = instant
      actual_interval = after - @offset - elapsed # actual number of nanos elapsed
      @drift_adjust = interval - Rational(actual_interval, 1_000_000_000)
      @drift_adjust = 0.5 if @drift_adjust > 0.5
      @drift_adjust = -0.5 if @drift_adjust < -0.5
    end
  end

  class StampingTimer < Timer
    def capture!; end
    def timestamp; end
  end

  class OffsetTimer < StampingTimer
    attr_reader :nanos, :format

    def initialize(format: :seconds)
      super()
      @format = format
      @base = offset
    end

    def capture!
      @nanos = instant - @base
    end

    def seconds
      Rational(@nanos, 1_000_000_000)
    end

    def millis
      Rational(@nanos, 1_000_000)
    end

    def micros
      Rational(@nanos, 1_000)
    end

    def timestamp
      case format
      when :nanos
        nanos.to_s
      when :micros
        micros.to_f.to_s
      when :millis
        millis.to_f.to_s
      when :seconds
        seconds.to_f.to_s
      end
    end
  end

  class AbsoluteTimer < StampingTimer
    attr_reader :format

    def initialize(format: '%Y-%m-%dT%H:%M:%S.%L%z')
      super()
      @format = format
    end

    def capture!
      @captured = Time.now
    end

    def timestamp
      @captured.strftime(format)
    end
  end
end
