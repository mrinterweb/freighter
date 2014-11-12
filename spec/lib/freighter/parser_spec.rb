require 'spec_helper'
require 'pry'

describe Freighter::Parser do
  let(:config_path) { File.expand_path('../../../../config/freighter.example.yml', __FILE__) }

  before do
    # allow(YAML).to receive(:load_file).and_return(:sample_config)
    Freighter.options.environment = 'staging'
  end

  subject { Freighter::Parser.new(config_path) }

  describe "images" do
    subject do
      Freighter.options.environment = 'production'
      Freighter::Parser.new(config_path).images('prod1.example.com')
    end

    context "deploy all" do
      before do
        Freighter.options.deploy_all = true
        Freighter.options.app_name = nil
      end

      it "should retrieve images" do
        expect(subject.map { |h| h['name'] }).to eq ["organization/imageName:latest", "organization/otherImage:latest"]
      end
    end

    context "deploy one app" do
      before do
        Freighter.options.deploy_all = false
        Freighter.options.app_name = 'otherApp'
      end

      it "should find one image" do
        expect(subject.length).to eq 1
        expect(subject.first['name']).to eq "organization/otherImage:latest"
      end
    end

    context "app not found" do
      before do
        Freighter.options.deploy_all = false
        Freighter.options.app_name = nil
      end

      it "should raise an exception" do
        expect { subject }.to raise_error RuntimeError, "app(s) to deploy not specified"
      end
    end
  end # images

  describe "environment" do
    it "should fetch the right environment" do
      expect(subject.environment).to have_key('hosts')
      expect(subject.environment['hosts'].first.fetch('host')).to eq 'staging.example.com'
    end
  end # environment

end
