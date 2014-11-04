module Freighter
  class Deploy
    attr_reader :logger, :config

    def initialize
      Parse.new OPTIONS.config_path
      @logger = LOGGER
      @config = OPTIONS.config
      @connection_config = @config.fetch('connection')
      environments = @config.fetch('environments')
      @environment = environments.fetch(OPTIONS.environment) rescue logger.config_error("environments/#{OPTIONS.environment}")

      connection_type = @connection_config['type']
      case connection_type
      when 'ssh'
        deploy_with_ssh
      else
        logger.error "Unknown configuration option for type: #{connection_type}"
      end
    end

    def deploy_with_ssh
      ssh_options = @connection_config.fetch('ssh_options')
      ssh_options.extend Helpers::Hash
      ssh_options = ssh_options.symbolize_keys
      @environment.fetch('hosts').each do |host|
        ssh = SSH.new(host, ssh_options)
        ssh.start do |shell|
          puts shell.exec! 'ls -l'
        end
      end
    end

  end
end