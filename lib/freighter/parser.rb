require 'yaml'

module Freighter
  class Parser
    attr_reader :config

    def initialize(config_path)
      begin
        @config = opts.config = YAML.load_file(config_path)
        LOGGER.debug "config file parsed"
      rescue Errno::ENOENT, Psych::SyntaxError => e
        LOGGER.error "Error parsing freighter config file.\n  path: #{config_path}\n  #{e}"
      rescue
        LOGGER.error "There is something wrong with the path to your yaml config file: #{config_path}\n  #{$!.message}"
      end
      
      # Do some basic checking to make sure the config file has what we need
      %w[environments connection/type].each { |option| test_config_option option }
      set_defaults
    end

    def opts
      OPTIONS
    end

    # recursively tests for keys in a nested hash by separating nested keys with '/'
    def test_config_option(option, opt_array=[], context=nil)
      opts_2_test = option.split('/')
      opts_2_test.each_with_index do |opt, i|
        opt_array << opt
        context ||= opts.config
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

    def images(host)
      host_config = environment.fetch('hosts').detect { |h| h.fetch('host') == host }
      host_images = host_config.fetch('images')
      raise "app(s) to deploy not specified" unless opts.deploy_all or opts.app_name
      if opts.deploy_all
        host_images
      else
        host_images.select do |host_image|
          !host_image.fetch('containers').detect do |container|
            container['name'] == opts.app_name
          end.nil?
        end
      end
    end

    def environment
      begin
        config.fetch('environments').fetch(opts.environment)
      rescue KeyError => e
        LOGGER.error "Error fetching environment: #{e.message}"
      end
    end
    
    private

      def set_defaults
        opts.config.tap do |conf|
          conf['connection']['docker'] ||= {}
          conf['connection']['docker']['socket'] ||= 'unix:///var/run/docker.sock'
          conf['connection']['docker']['port']   ||= nil
        end
        opts.deploy_all ||= false
        opts.pull_image = true if opts.pull_image.nil?
      end

  end
end
