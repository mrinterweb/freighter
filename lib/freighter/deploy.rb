module Freighter
  class Deploy
    attr_reader :logger, :config

    def initialize
      @logger = LOGGER
      Parse.new OPTIONS.config_path
      @config = OPTIONS.config

      connection = config.fetch('connection') rescue logger.error("connection not defined")
      connection_type = connection.fetch('type') rescue logger.config_error("connection type not defined")

      case connection_type
      when 'ssh'
        deploy_with_ssh
      else
        logger.error "Unknown configuration option for type: #{connection_type}"
      end
    end

    def deploy_with_ssh
      ssh = SSH.new(config)
      ssh.proxy do
        puts "Fantastic"
      end
    end

  end
end
