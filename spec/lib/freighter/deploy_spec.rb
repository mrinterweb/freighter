require 'spec_helper'

describe Freighter::Deploy do

  before do
    options = Freighter.options
    options.config_path = "#{BASE_DIR}/config/freighter.example.yml"
    options.environment = "staging"
    expect_any_instance_of(Freighter::Deploy).to receive(:deploy_with_ssh)
  end
  
  context "private methods" do
    subject { Freighter::Deploy.new }

    describe "ports" do

      it "should match port mapping with IP address" do
        mapping = "0.0.0.0:80->90"
        port_map = subject.send(:map_ports, mapping)
        expect(port_map.ip).to eq "0.0.0.0"
        expect(port_map.host).to eq 80
        expect(port_map.container).to eq 90
      end

      it "should be able to accept a mapping without an IP address" do
        mapping = "80->90"
        port_map = subject.send(:map_ports, mapping)
        expect(port_map.ip).to be_nil
        expect(port_map.host).to eq 80
        expect(port_map.container).to eq 90
      end

      it "should raise an exception if port mapping format is incorrect" do
        mapping = ""
        expect { subject.send(:ports, mapping) }.to raise_error
      end
    end  
  end
end
