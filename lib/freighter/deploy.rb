require 'docker'

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
      @environment.fetch('hosts').each_with_index do |host, i|
        ssh = SSH.new(host, ssh_options)
        port = 7000 + i
        docker_api = DockerRestAPI.new("http://localhost:#{port}")

        ssh.tunneled_proxy(port) do |session|
          setup_docker_client(port)

          # pull the latest image
          # Docker::Image.create 'fromImage' => 'org/image:latest'
          binding.pry
        end
      end
    end

    def setup_docker_client(port)
      Docker.url = "http://localhost:#{port}"
      
      # check docker connection
      begin
        logger.debug "Requesting docker version"
        # excon = Excon.new "http://localhost:#{port}"
        # response = excon.get path: '/containers/json'
        response = Docker.version
        Docker.authenticate!('username' => ENV['DOCKER_HUB_USER_NAME'], 'password' => ENV['DOCKER_HUB_PASSWORD'], 'email' => ENV['DOCKER_HUB_EMAIL'])
        puts response.inspect
      rescue Excon::Errors::SocketError => e
        logger.error e.message
      end
    end

  end
end
