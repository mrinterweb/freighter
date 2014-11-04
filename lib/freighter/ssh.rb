module Freighter
  class SSH
    def initialize(ssh_conf)
      @ssh_conf = ssh_conf
    end

    def proxy(&block)
      yield 
    end
  end
end
