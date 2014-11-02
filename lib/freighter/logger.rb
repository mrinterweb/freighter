module Freighter
  class Logger
    def initialize(options)
      @verbose = options.verbose
    end

    def log(str, verbose=false)
      if @verbose or verbose != :verbose
        puts str
      end
    end

    def error(str)
      puts str
      puts "Freighter hit an iceburg. To the life boats. All is lost. :("
      exit -1
    end
  end
end
