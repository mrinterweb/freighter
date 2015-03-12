require 'docker'
require 'thread'
require 'thwait'

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
        @current_host_name = host_name
        images = @parser.images(host_name)

        ssh = SSH.new(host_name, ssh_options)
        local_port = 7000 + i
        # docker_api = DockerRestAPI.new("http://localhost:#{local_port}")

        ssh.tunneled_proxy(local_port) do |session|

          logger.debug msg "Connected"
          begin
            # The timeout is needed in the case that we are unable to communicate with the docker REST API
            Timeout::timeout(5) do
              setup_docker_client(local_port)
            end
          rescue Timeout::Error
            ssh.thread.exit
            logger.error msg "Could not reach the docker REST API"
          end

          
          images.each do |image|
            image_name = image['name']
            # pull image
            if OPTIONS.pull_image
              logger.info msg "Pulling image: #{image_name}" 
              pull_response = Docker::Image.create 'fromImage' => image_name
            else
              logger.info msg "Skip pull image"
              logger.error msg "Skipping is not yet implemented. Please run again without the --no-pull option"
            end

            # find existing images on the machine
            image_ids = Docker::Image.all.select do |img|
              img.info['RepoTags'].member?(image_name)
            end.map { |img| img.id[0...12] }

            logger.info msg "Existing image(s) found #{image_ids.join(', ')}"

            # determine if a the latest version of the image is currently running
            matching_containers = containers_matching_port_map(Docker::Container.all, image['containers'].map { |c| c['port_mapping'] })

            # stop previous container and start up a new container with the latest image
            stopped_containers = []
            current_running_containers = []
            matching_containers.each do |container|
              if pull_response.id =~ /^#{container.info['Image']}/
                current_running_containers << container
              else
                Docker::Container.get(container.id).stop
                stopped_containers << container
              end
            end
            if !current_running_containers.empty? and stopped_containers.empty?
              logger.info msg "Container already running with the latest image: #{pull_response.id}"
            else 
              logger.info msg "Stopped containers: #{stopped_containers.map(&:info).map(&:to_json)}"
              results = update_containers matching_containers, image
              logger.info msg "Finished:"
              logger.info msg "  started: #{results[:started]}"
              logger.info msg "  stopped: #{results[:stopped]}"
              logger.info msg "  started container ids: #{results[:container_ids_started]}"
              
              # cleanup old containers
              cleanup_old_containers
              # cleanup unused/outdated images
              cleanup_dangling_images
            end
          end
        end
      end
    end

    private

      # Used for logging to prefix log messages with the current host
      def msg(message)
        "#{@current_host_name}: #{message}"
      end

      # Sets up the Docker gem by setting the local URL and authenticating to the host's REST API
      def setup_docker_client(local_port)
        Docker.url = "http://localhost:#{local_port}"
        Docker.connection.options[:scheme] = 'http'
        begin
          logger.debug "Requesting docker version"
          response = Docker.version
          logger.debug "Docker version: #{response.inspect}"
          logger.debug "Requesting docker authenticaiton"
          response = Docker.authenticate!('username' => ENV['DOCKER_HUB_USER_NAME'], 'password' => ENV['DOCKER_HUB_PASSWORD'], 'email' => ENV['DOCKER_HUB_EMAIL'])
          logger.debug "Docker authentication: #{response.inspect}"
        rescue Excon::Errors::SocketError => e
          abort e.message
        rescue Exception => e
          abort e.message
        end
      end

      def containers_matching_port_map(containers, port_mappings)
        port_mappings.map do |port_map|
          ports = map_ports(port_map)
          containers.select do |c|
            c.info['Ports'].detect do |p|
              p['PrivatePort'] == ports.container && p['PublicPort'] == ports.host
            end
          end
        end.compact.flatten
      end

      PortMap = Struct.new(:ip, :host, :container)
      def map_ports(port_map)
        # for some unknown reason, containers started without a port mapping specified
        # are getting a default port mapping of 80/tcp. This is why a default port map is 
        # being assigned to port 80
        return PortMap.new(nil, nil, 80) if port_map.nil?
        port_map.match(/^(\d{1,3}\.[\.0-9]*)?:?(\d+)->(\d+)$/)
        begin
          raise if $2.nil? or $3.nil?
          PortMap.new($1, $2.to_i, $3.to_i)
        rescue
          raise "port_mappings needs to be in the format of <ip-address>:<host-port-number>-><container-port-number>. received: #{port_map}"
        end
      end

      def update_containers(existing_containers=[], image)
        totals = { stopped: 0, started: 0, container_ids_started: [] }
        # stop the existing matching containers
        existing_containers.map do |container|
          Thread.new do
            existing_container = Docker::Container.get(container.id)
            logger.info msg "Stopping container: #{contianer.id}"
            existing_container.stop
            existing_container.wait()
            logger.info msg "Container stopped (#{container.id}"
            totals[:stopped] += 1
          end
        end.join

        # start up some new containers
        image['containers'].map do |container|
          port_map = map_ports(container['port_mapping'])

          # env = container['env'].inject("") { |r, (k,v)| r << "#{k}='#{v}',\n" }
          env = container['env'].map { |k,v| "#{k}=#{v}" }
          container_options = {
            "Image" => image['name'],
            "Env" => env
          }

          start_options = {}

          if port_map.host
            container_options.merge!({ "ExposedPorts" => { "#{port_map.container}/tcp" => {} } })
            start_options.merge!({
              "PortBindings" => {
                "#{port_map.container}/tcp" => [{ "HostPort" => port_map.host.to_s, "HostIp" => port_map.ip }]
              }
            })
            logger.info msg "Starting container with port_mapping: host #{[port_map.ip, port_map.host].join(':')}, container #{port_map.container}"
          end

          new_container = Docker::Container.create container_options

          new_container.start start_options
          totals[:container_ids_started] << new_container.id
          logger.info msg "New container started with id: #{new_container.id}"
          totals[:started] += 1
        end
        
        totals
      end

      # cleans up all exited containers
      def cleanup_old_containers
        thread_pool = []
        Docker::Container.all(all: true).select { |c| c.info['Status'] =~ /^Exited/ }.each do |container|
          thread_pool << Thread.new do
            logger.info msg "Removing container: #{container.info.to_json}"
            container.remove
          end
        end
        if thread_pool.empty?
          logger.info msg "No containers need to be cleaned up"
        else
          logger.info msg "Waiting for old containers to be cleaned up"
          ThreadsWait.all_waits(*thread_pool)
        end
      end

      def cleanup_dangling_images
        thread_pool = []
        Docker::Image.all(filters: '{"dangling":["true"]}').each do |image|
          thread_pool << Thread.new do
            image.remove
            logger.info msg "Removed image: #{image.info.to_json}"
          end
        end
        logger.info msg "Waiting for dangling images to be cleaned up"
        ThreadsWait.all_waits(*thread_pool)
      end

  end
end
