require 'net/ssh'
require 'net/ssh/proxy/socks5'

module Freighter
  class SSH
    def initialize(host, ssh_conf)
      @host = host
      @user = ssh_conf.fetch(:user_name)
      ssh_conf.delete(:user_name)
      @ssh_options = ssh_conf
    end

    def proxy
      docker_port = OPTIONS.config['connection']['docker']['port']
      Net::SSH::Proxy::SOCKS5.new(@host, docker_port, {user: @user}.merge(@ssh_options))
    end

    def tunneled_proxy(local_port, use_proxy=false, &block)
      options = use_proxy ? { proxy: proxy } : @ssh_options
      docker_port = OPTIONS.config['connection']['docker']['port']

      thread = Thread.new do
        Thread.current.thread_variable_set(:ssh_tunnel_established, false)

        Net::SSH.start(@host, @user, options) do |session|
          session.forward.local(local_port, "0.0.0.0", docker_port)

          Thread.current.thread_variable_set(:ssh_tunnel_established, true)
          continue_session = true

          int_pressed = false
          trap("INT") { int_pressed = true }
          session.loop(0.1) { continue_session && !int_pressed }
        end
      end

      while thread.thread_variable_get(:ssh_tunnel_established) != true
        sleep 0.1
      end

      yield
      sleep 0.5
      thread.exit
    end

  end
end
