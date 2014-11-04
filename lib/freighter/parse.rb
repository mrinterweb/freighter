require 'yaml'

module Freighter
  class Parse
    def initialize(config_path)
      begin
        OPTIONS.config = YAML.load_file(config_path)
        LOGGER.debug "config file parsed"
      rescue Errno::ENOENT => e
        LOGGER.error "Error parsing freighter config file.\n  path: #{config_path}\n  #{e}"
      rescue
        LOGGER.error "There is something wrong with the path to your yaml config file: #{config_path}\n  #{$!.message}"
      end
    end
  end
end
