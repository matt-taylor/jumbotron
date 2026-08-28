# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Canonical::UpsertTeam do
  let(:observed_at) { Time.zone.parse("2026-08-27 15:00:00 UTC") }
  let(:change_set) { Jumbotron::Canonical::ChangeSet.new }
  let(:provider_id) { "2" }

  def team_input(name:, provider_id: self.provider_id, nickname: nil)
    Jumbotron::Canonical::TeamInput.new(
      provider_identities: [
        Jumbotron::Canonical::ProviderIdentityRef.new(
          provider: "espn",
          namespace: "team",
          id: provider_id
        )
      ],
      name: name,
      nickname: nickname
    )
  end

  def upsert!(name:, provider_id: self.provider_id, nickname: nil, change_set: self.change_set)
    described_class.call(
      team_input: team_input(name: name, provider_id: provider_id, nickname: nickname),
      observed_at: observed_at,
      change_set: change_set
    )
  end

  it "assigns an immutable semantic key from the display name on create" do
    result = upsert!(name: "Buffalo Bills")

    expect(result).to be_success
    team = result.data[:team]
    expect(team.key).to eq("buffalo-bills")
    expect(Jumbotron::TeamKey.valid_format?(team.key)).to be(true)
    expect(team.key).not_to eq(provider_id)
  end

  it "never exposes ESPN provider id as Team.key" do
    result = upsert!(name: "Buffalo Bills", provider_id: "2")

    expect(result.data[:team].key).to eq("buffalo-bills")
    expect(result.data[:team].key).not_to eq("2")
  end

  it "derives the same semantic key for equivalent names across independent creates" do
    first = upsert!(name: "Buffalo Bills", provider_id: "2").data[:team]
    expect(first.key).to eq("buffalo-bills")

    first.provider_identities.destroy_all
    first.destroy!

    recreated = upsert!(name: "Buffalo Bills", provider_id: "2").data[:team]
    expect(recreated.key).to eq("buffalo-bills")
    expect(Jumbotron::TeamKey.normalize("Buffalo Bills")).to eq("buffalo-bills")
  end

  it "does not regenerate key when the display name changes" do
    created = upsert!(name: "Buffalo Bills").data[:team]
    expect(created.key).to eq("buffalo-bills")

    renamed = upsert!(name: "Buffalo Football Club").data[:team]
    expect(renamed.id).to eq(created.id)
    expect(renamed.name).to eq("Buffalo Football Club")
    expect(renamed.key).to eq("buffalo-bills")
  end

  it "does not update key on provider re-upsert with the same identity" do
    created = upsert!(name: "Buffalo Bills").data[:team]
    created.update_columns(key: "buffalo-bills") # rubocop:disable Rails/SkipsModelValidations

    again = upsert!(name: "Buffalo Bills").data[:team]
    expect(again.key).to eq("buffalo-bills")
  end

  it "enforces unique keys across teams" do
    upsert!(name: "Buffalo Bills", provider_id: "2")
    other = upsert!(name: "Buffalo Bills", provider_id: "3").data[:team]

    expect(Jumbotron::Team.where(key: "buffalo-bills").count).to eq(1)
    expect(other.key).to match(/\Abuffalo-bills-\d+\z/)
  end

  context "when nickname is provided on create" do
    subject(:result) { upsert!(name: "Buffalo Bills", nickname: "Bills") }

    it "persists nickname" do
      expect(result).to be_success
      expect(result.data[:team].nickname).to eq("Bills")
    end
  end

  context "when nickname is provided on update" do
    before { upsert!(name: "Buffalo Bills", nickname: "Bills") }

    subject(:result) { upsert!(name: "Buffalo Bills", nickname: "Buffalo") }

    it "updates nickname" do
      expect(result).to be_success
      expect(result.data[:team].nickname).to eq("Buffalo")
    end
  end

  context "when nickname input is nil on re-upsert" do
    before { upsert!(name: "Buffalo Bills", nickname: "Bills") }

    subject(:result) { upsert!(name: "Buffalo Bills", nickname: nil) }

    it "leaves the existing nickname unchanged" do
      expect(result).to be_success
      expect(result.data[:team].nickname).to eq("Bills")
    end
  end
end
