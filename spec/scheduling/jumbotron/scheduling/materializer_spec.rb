# frozen_string_literal: true

require "tmpdir"

RSpec.describe Jumbotron::Scheduling::Materializer do
  it "delegates to the detected backend" do
    backend = instance_double(Jumbotron::Scheduling::Backends::SolidQueue)
    schedules = Jumbotron::Scheduling::DesiredSchedules.call
    allow(Jumbotron::Scheduling::DetectIntegration).to receive(:call).and_return(backend)
    allow(backend).to receive(:materialize)

    described_class.call(schedules: schedules)

    expect(backend).to have_received(:materialize).with(schedules, path: nil)
  end

  it "passes a Solid Queue path override through to the backend" do
    backend = Jumbotron::Scheduling::Backends::SolidQueue.new
    Dir.mktmpdir do |dir|
      path = Pathname.new(dir).join("recurring.yml")
      described_class.call(backend: backend, solid_queue_path: path)

      doc = YAML.safe_load_file(path)
      expect(doc.fetch(Rails.env).keys).to include("jumbotron:espn_nfl:live")
    end
  end
end
