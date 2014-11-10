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
      
      # Do some basic checking to make sure the config file has what we need
      %w[environments connection/type].each { |option| test_config_option option }
      set_defaults
    end

    # recursively tests for keys in a nested hash by separating nested keys with '/'
    def test_config_option(option, opt_array=[], context=nil)
      opts_2_test = option.split('/')
      opts_2_test.each_with_index do |opt, i|
        opt_array << opt
        context ||= OPTIONS.config
        begin
          if next_opt = opts_2_test[i+1]
            new_context = context.fetch(opt)
            test_config_option(next_opt, opt_array.clone, new_context.clone)
          end
        rescue KeyError
          LOGGER.config_error opt_array.join('/')
        end
      end
    end

    def set_defaults
      conf = OPTIONS.config
      conf['connection']['docker'] ||= {}
      conf['connection']['docker']['socket'] ||= 'unix:///var/run/docker.sock'
      conf['connection']['docker']['port']   ||= nil
      OPTIONS.pull_image = true if OPTIONS.pull_image.nil?
    end
  end
end
