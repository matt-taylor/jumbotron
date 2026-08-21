# frozen_string_literal: true

RSpec.describe Jumbotron::Providers::Espn::ProviderFailure do
  def upstream(status: nil, cause: nil)
    details = status.nil? ? {} : { status: status }
    CommandTower::Clients::Errors::UpstreamError.new(
      message: "boom",
      details: details,
      cause: cause
    )
  end

  it "advances on transport causes and 5xx" do
    expect(described_class.availability_failure?(
             upstream(cause: CommandTower::Clients::Transport::Error.new("timeout"))
           )).to be(true)
    expect(described_class.availability_failure?(upstream(status: 503))).to be(true)
    expect(described_class.availability_failure?(upstream(status: 500))).to be(true)
  end

  it "does not advance on 4xx, deserialization, or transform errors" do
    expect(described_class.availability_failure?(upstream(status: 404))).to be(false)
    expect(described_class.availability_failure?(
             CommandTower::Clients::Errors::DeserializationError.new(
               message: "bad",
               details: { path: "", expected: "x", actual: "y", rule: "type", messages: [] }
             )
           )).to be(false)
    expect(described_class.availability_failure?(
             Jumbotron::Adapters::TransformError.new("nope")
           )).to be(false)
  end
end
