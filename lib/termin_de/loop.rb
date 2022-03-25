# frozen_string_literal: true

require 'logger'

module TerminDe
  # Endless loop for querying the burgeramt webpage
  class Loop
    # NOTE : We don't want to be limited by service protection
    REQUEST_INTERVAL_IN_SECONDS = 60

    def initialize(options)
      @options = options
      @fails = 0

      @logger = Logger.new(STDOUT)
      @logger.datetime_format = '%Y-%m-%d %H:%M:%S'
      @logger.level = Logger::INFO
    end

    def run
      repeat do
        calendar = Calendar.new(@options)

        if calendar.earlier?
          termin_found(calendar.earlier_termin)
        else
          @logger.info 'Nothing ...'
        end

        sleep(REQUEST_INTERVAL_IN_SECONDS)
      end
    end

    private

    def repeat
      (1..@options.times).each do |i|
        @logger.info "[#{iteration(i)}] Looking for available slots after #{@options.after_date} and before #{@options.before_date}"
        begin
          yield
        rescue Exception => e
          # NOTE : Arrrgh, Curb doesn't nest exceptions
          raise unless e.class.name =~ /Curl/
          
          @fails += 1
          pause_when(@fails)
        end
      end
    end

    def pause_when(fails)
      num = (Math.log10(fails) * REQUEST_INTERVAL_IN_SECONDS / 2 + REQUEST_INTERVAL_IN_SECONDS).to_i
      @logger.warn "Woooops, slow down ... pause for #{num} seconds"
      sleep(num)
    end

    def termin_found(termin)
      @logger.info "Found new [#{termin.date}] → #{termin.link}"
      `#{@options.command % termin.to_h}` if @options.command_given?
    end

    def iteration(i)
      limit = @options.times.infinite? ? '∞' : @options.times
      "#{i}/#{limit}"
    end
  end
end
