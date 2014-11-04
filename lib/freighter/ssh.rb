require 'net/ssh'

module Freighter
  class SSH
    def initialize(host, ssh_conf)
      @host = host
      @user = ssh_conf.fetch(:user_name)
      ssh_conf.delete(:user_name)
      @ssh_options = ssh_conf
    end

    def proxy(&block)
      # todo - not ready
      yield 
    end

    def start(&block)
      Net::SSH.start(@host, @user, @ssh_options) do |ssh|
        yield ssh
      end
    end
  end
end
