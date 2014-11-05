require 'logger'

module Freighter
  class Logger
    attr_reader :logger

    def initialize
      @logger = ::Logger.new(STDOUT)
      logger.formatter = ->(severity, time, progname, msg) { "#{severity}: #{msg}\n" }
    end

    def method_missing(meth, *args, &block)
      logger.level = OPTIONS.verbose ? ::Logger::DEBUG : ::Logger::INFO
      logger.send(meth, *args)
    end

    def config_error(str)
      error "Config error: #{str} not defined"
    end

    def error(str)
      logger.error str
      logger.error "Freighter hit an iceburg. To the life boats. All is lost. A truely unfortunate day in nautical affairs :("
      exit -1
    end
     
  end
end
