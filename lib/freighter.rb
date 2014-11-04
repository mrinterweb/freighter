Dir[File.join(File.dirname(__FILE__), 'freighter', '*')].each do |file|
  require file
end
require 'ostruct'

module Freighter

  def self.options; OPTIONS end
  def self.logger; LOGGER end

  OPTIONS = OpenStruct.new
  LOGGER  = Logger.new

end

