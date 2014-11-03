require 'logger'

module Freighter
  class Logger
    attr_reader :logger

    def initialize(options)
      @logger = ::Logger.new(STDOUT)
      @logger.formatter = ->(severity, time, progname, msg) { "#{severity}: #{msg}\n" }
      logger.level = options.verbose ? ::Logger::DEBUG : ::Logger::INFO
    end

    def method_missing(meth, *args, &block)
      logger.send(meth, *args)
    end

    def error(str)
      logger.error str
      logger.error "Freighter hit an iceburg. To the life boats. All is lost. :("
      exit -1
    end
     
  end
end
