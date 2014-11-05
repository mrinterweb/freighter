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
        host_name = host.fetch('host')
        images = host.fetch('images')

        ssh = SSH.new(host_name, ssh_options)
        local_port = 7000 + i
        # docker_api = DockerRestAPI.new("http://localhost:#{local_port}")

        ssh.tunneled_proxy(local_port) do |session|
          logger.debug "connected to #{host_name}"
          begin
            Timeout::timeout(5) do
              setup_docker_client(local_port)
            end
          rescue Timeout::Error
            ssh.thread.exit
            logger.error "Could not reach the docker host"
          end

          images.each do |image|
            # pull image
            Docker::Image.create 'fromImage' => image
          end
        end
      end
    end

    def setup_docker_client(local_port)
      Docker.url = "http://localhost:#{local_port}"
      begin
        # excon = Excon.new "http://localhost:#{local_port}"
        # response = excon.get path: '/containers/json'

        logger.debug "Requesting docker version"
        response = Docker.version
        logger.debug "Docker version: #{response.inspect}"
        logger.debug "Requesting docker authenticaiton"
        response = Docker.authenticate!('username' => ENV['DOCKER_HUB_USER_NAME'], 'password' => ENV['DOCKER_HUB_PASSWORD'], 'email' => ENV['DOCKER_HUB_EMAIL'])
        logger.debug "Docker authentication: #{response.inspect}"
      rescue Excon::Errors::SocketError => e
        logger.error e.message
      end
    end

  end
end
