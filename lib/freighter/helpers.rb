module Freighter
  module Helpers
    module Hash
      # this is not convert nested keys
      def symbolize_keys
        self.inject({}) { |result, (key,val)| result[key.to_sym] = val; result }
      end
    end
  end
end
