require 'yaml'
require 'pry'
require 'freighter/logger'

module Freighter
  class Parse
    def initialize(options)
      @logger = Logger.new options
      @config_path = options.config_path
      begin
        @config = YAML.load_file(@config_path)
        @logger.log "config file parsed", :verbose
      rescue Errno::ENOENT => e
        @logger.error "Error parsing freighter config file.\n  path: #{@config_path}\n  #{e}"
      end
    end
  end
end
