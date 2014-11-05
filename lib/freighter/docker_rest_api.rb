require 'excon'
require 'json'

module Freighter
  class DockerRestAPI
    
    def initialize(url)
      @base_url = url
      @http = Excon.new url
    end

    # authentication should not be necessary if the user is already authenticated with the docker client on the host
    def authenticate
      request { post(path: '/auth', body: JSON.dump({ 'username' => ENV['DOCKER_HUB_USER_NAME'], 'password' => ENV['DOCKER_HUB_PASSWORD'], 'email' => ENV['DOCKER_HUB_EMAIL'] }), headers: { "Content-Type" => "application/json" }) }
    end

    # This pulls a specified image
    # def pull(image, repo, tag='latest')
    def pull(tag)
      request do
        post(path: "/images/create", query: { tag: tag })
      end
    end

    # returns all running containers
    def running_containers
      request do
        get(path: '/containers/json')
      end
    end

    def list_images
      request { get path: '/images/json' }
    end

    protected

      ResponseObject = Struct.new(:body_hash, :status)

      def request(&block)
        begin
          binding.pry
          response = yield
        rescue Excon::Errors::SocketError => e
          logger.error e.message
        end

        status = response.status
        if status >= 200 and status < 300
          begin
          ResponseObject.new JSON.parse(response.body), status
          rescue JSON::ParserError => e
            binding.pry
          end
        else
          LOGGER.error "Could not process request:\n    request: #{@last_request_args.inspect}\n    response: #{response.inspect}"
        end
      end

      %w[get post put delete].each do |verb|
        define_method verb.to_sym do |*args|
          @last_request_args = args
          @http.send(verb.to_sym, *args)
        end
      end

  end
end
