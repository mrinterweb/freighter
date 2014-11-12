require 'docker'

module Freighter
  class Deploy
    attr_reader :logger, :config

    def initialize
      @parser = Parser.new OPTIONS.config_path
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
          msg = ->(m) { "#{host_name}: #{m}" } 

          logger.debug msg["Connected"]
          begin
            # The timeout is needed in the case that we are unable to communicate with the docker REST API
            Timeout::timeout(5) do
              setup_docker_client(local_port)
            end
          rescue Timeout::Error
            ssh.thread.exit
            logger.error msg["Could not reach the docker REST API"]
          end

          
          images.each do |image|
            image_name = image['name']
            # pull image
            if OPTIONS.pull_image
              logger.info msg["Pulling image: #{image_name}"] 
              pull_response = Docker::Image.create 'fromImage' => image_name
            else
              logger.info msg["Skip pull image"]
              logger.error msg["Skipping is not yet implemented. Please run again without the --no-pull option"]
            end

            # find existing images on the machine
            image_ids = Docker::Image.all.select do |img|
              img.info['RepoTags'].member?(image_name)
            end.map { |img| img.id[0...12] }

            logger.info msg["Existing image(s) found #{image_ids.join(', ')}"]

            # determine if a the latest version of the image is currently running
            matching_containers = containers_matching_port_map(Docker::Container.all, image['containers'].map { |c| c['port_mapping'] })
            if image_ids.member?(pull_response.id) && !matching_containers.empty?
              logger.info msg["Container already running with the latest image: #{pull_response.id}"]
            else 
              # stop previous container and start up a new container with the latest image
              results = update_containers matching_containers, image
              binding.pry
            end
          end
        end
      end
    end

    private

      # Sets up the Docker gem by setting the local URL and authenticating to the host's REST API
      def setup_docker_client(local_port)
        Docker.url = "http://localhost:#{local_port}"
        begin
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

      def containers_matching_port_map(containers, port_mappings)
        port_mappings.map do |port_map|
          ports = ports(port_map)
          containers.select do |c|
            c.info['Ports'].detect do |p|
              p['PrivatePort'] == ports.container && p['PublicPort'] == ports.host
            end
          end
        end.flatten
      end

      PortMap = Struct.new(:ip, :host, :container)
      def ports(port_map)
        port_map.match(/^(\d{1,3}\.[\.0-9]*)?:?(\d+)->(\d+)$/)
        begin
          raise if $2.nil? or $3.nil?
          PortMap.new($1, $2.to_i, $3.to_i)
        rescue
          raise "port_mappings needs to be in the format of <ip-address>:<host-port-number>-><container-port-number>. received: #{port_map}"
        end
      end

      def update_containers existing_containers=[], image
        totals = { stopped: 0, started: 0 }
        # stop the existing matching containers
        existing_containers.map do |container|
          Thread.new do
            existing_container = Docker::Container.get(container.id)
            logger.info "Stopping container: #{contianer.id}"
            existing_container.stop
            existing_container.wait()
            logger.info "Container stopped (#{container.id}"
            totals[:stopped] += 1
          end
        end.join

        # start up some new containers
        image['containers'].map do |container|
          port_map = ports(container['port_mapping'])

          # env = container['env'].inject("") { |r, (k,v)| r << "#{k}='#{v}',\n" }
          env = container['env'].map { |k,v| "#{k}=#{v}" }
          container_options = {
            "Image" => image['name'],
            "ExposedPorts" => { "#{port_map.container}/tcp" => {} },
            "Env" => env
          }

          new_container = Docker::Container.create container_options
          logger.info "Starting container with port_mapping: host #{[port_map.ip, port_map.host].join(':')}, container #{port_map.container}"
          new_container.start(
            "PortBindings" => { "#{port_map.container}/tcp" => [{ "HostPort" => port_map.host.to_s, "HostIp" => port_map.ip }] }
          )
          new_container.wait()
          logger.info "New container started with id: #{new_container.id}"
          totals[:started] += 1
        end
        
        totals
      end

  end
end
