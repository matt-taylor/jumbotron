# frozen_string_literal: true

RSpec.describe Jumbotron::Scheduling::DetectIntegration do
  it "selects Solid Queue when the ActiveJob adapter is solid_queue" do
    allow(ActiveJob::Base).to receive(:queue_adapter_name).and_return("solid_queue")

    expect(described_class.call).to be_a(Jumbotron::Scheduling::Backends::SolidQueue)
  end

  it "selects Sidekiq-Cron when the adapter is sidekiq and Sidekiq::Cron::Job is defined" do
    allow(ActiveJob::Base).to receive(:queue_adapter_name).and_return("sidekiq")
    stub_const("Sidekiq::Cron::Job", Jumbotron::SpecSupport::FakeSidekiqCronJob)

    expect(described_class.call).to be_a(Jumbotron::Scheduling::Backends::SidekiqCron)
  end

  it "fails when Sidekiq is configured without Sidekiq-Cron" do
    allow(ActiveJob::Base).to receive(:queue_adapter_name).and_return("sidekiq")
    hide_const("Sidekiq::Cron::Job") if defined?(Sidekiq::Cron::Job)

    expect { described_class.call }.to raise_error(
      Jumbotron::Scheduling::UnsupportedIntegrationError,
      /adapter :sidekiq/
    )
  end

  it "fails clearly for :test" do
    allow(ActiveJob::Base).to receive(:queue_adapter_name).and_return("test")

    expect { described_class.call }.to raise_error(
      Jumbotron::Scheduling::UnsupportedIntegrationError,
      /adapter :test.*Solid Queue, Sidekiq \+ Sidekiq-Cron/m
    )
  end

  it "fails clearly for :async" do
    allow(ActiveJob::Base).to receive(:queue_adapter_name).and_return("async")

    expect { described_class.call }.to raise_error(
      Jumbotron::Scheduling::UnsupportedIntegrationError,
      /adapter :async/
    )
  end
end
