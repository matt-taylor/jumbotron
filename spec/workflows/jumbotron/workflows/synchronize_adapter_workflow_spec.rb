# frozen_string_literal: true

RSpec.describe Jumbotron::Workflows::SynchronizeAdapterWorkflow do
  after { Jumbotron::Clients.reset_providers! }

  before do
    Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered?
  end

  let(:league) { create(:jumbotron_league) }
  let(:fixture_root) { Jumbotron::Engine.root.join("spec/fixtures/espn/nfl") }
  let(:observed_at) { Time.utc(2026, 8, 12, 18, 0, 0) }

  def seed_transport!(body)
    transport = Jumbotron::SpecSupport::FakeTransport.new do |_request|
      CommandTower::Clients::Transport::Response.build(status: 200, body: body, duration_ms: 1)
    end
    Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport))
    transport
  end

  def team_ref(id)
    Jumbotron::Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "team", id: id.to_s)
  end

  def game_input(attrs = {})
    Jumbotron::Canonical::GameInput.new(
      provider_identities: [
        Jumbotron::Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "event", id: "evt-1"),
        Jumbotron::Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "competition", id: "comp-1")
      ],
      scheduled_at: Time.utc(2025, 9, 5, 0, 20, 0),
      lifecycle: "scheduled",
      neutral_site: false,
      season_year: 2025,
      season_phase_key: "regular_season",
      schedule_group: Jumbotron::Canonical::ScheduleGroupInput.new(
        kind: "week",
        number: 1,
        name: "Week 1"
      ),
      venue: Jumbotron::Canonical::VenueInput.new(
        provider_identities: [
          Jumbotron::Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "venue", id: "venue-1")
        ],
        name: "Test Stadium"
      ),
      participants: [
        Jumbotron::Canonical::ParticipantInput.new(
          provider_identities: [team_ref(10)],
          team_name: "Home Team",
          role: "home",
          score: nil,
          result: nil
        ),
        Jumbotron::Canonical::ParticipantInput.new(
          provider_identities: [team_ref(20)],
          team_name: "Away Team",
          role: "away",
          score: nil,
          result: nil
        )
      ],
      **attrs
    )
  end

  def sync_input(games: [game_input], teams: [], at: observed_at)
    Jumbotron::Canonical::SyncInput.new(observed_at: at, games: games, teams: teams)
  end

  def stub_pre_transaction!(input)
    allow(Jumbotron::Services::Adapters::ValidateSyncRequest).to receive(:call).and_return(
      CommandTower::Services::ServiceResult.success(data: { league: league })
    )
    allow(Jumbotron::Services::Adapters::ExecuteEndpoint).to receive(:call).and_return(
      CommandTower::Services::ServiceResult.success(data: { sync_input: input })
    )
  end

  def apply_via_workflow!(input)
    stub_pre_transaction!(input)
    described_class.call(
      adapter: Jumbotron::Adapters::Espn::Nfl,
      endpoint: :scoreboard,
      league_id: league.id,
      observed_at: input.observed_at
    )
  end

  it "synchronizes via Validate → Execute → transactional apply" do
    seed_transport!(fixture_root.join("scoreboard_2025_w1.json").read)

    result = described_class.call(
      adapter: Jumbotron::Adapters::Espn::Nfl,
      endpoint: :scoreboard,
      league_id: league.id,
      observed_at: observed_at,
      acquisition: { dates: 2025, season_type: 2, week: 1 }
    )

    expect(result).to be_success
    expect(result.payload[:games]).not_to be_empty
    expect(Jumbotron::Game.count).to be > 0
  end

  it "creates games, participants, identities, freshness, and observation history on first sync" do
    result = apply_via_workflow!(sync_input)

    expect(result).to be_success
    expect(result.payload[:historical_change_count]).to be > 0
    expect(result.payload[:observation_batch_id]).to be_present

    game = Jumbotron::Game.find(result.payload[:games].first.id)
    expect(game.lifecycle).to eq("scheduled")
    expect(game.observed_at).to eq(observed_at)
    expect(game.changed_at).to eq(observed_at)
    expect(game.game_participants.count).to eq(2)
    expect(game.provider_identities.where(object_namespace: %w[event competition]).count).to eq(2)
    expect(Jumbotron::Season.find_by(league_id: league.id, name: "2025")).to be_present
    expect(game.schedule_group).to have_attributes(kind: "week", number: 1, name: "Week 1")
    expect(Jumbotron::HistoricalChange.where(subject_type: "Jumbotron::Game", subject_id: game.id).count).to be >= 1
  end

  it "no-ops material attrs and advances observed_at only" do
    first = apply_via_workflow!(sync_input)
    game = first.payload[:games].first
    first_changed = game.changed_at
    first_batch_count = Jumbotron::ObservationBatch.count

    later = observed_at + 1.hour
    second = apply_via_workflow!(sync_input(at: later))

    game.reload
    expect(second).to be_success
    expect(game.observed_at).to eq(later)
    expect(game.changed_at).to eq(first_changed)
    expect(second.payload[:observation_batch_id]).to be_nil
    expect(Jumbotron::ObservationBatch.count).to eq(first_batch_count)
  end

  it "records subject-level history when lifecycle changes" do
    apply_via_workflow!(sync_input)
    later = observed_at + 2.hours

    result = apply_via_workflow!(
      sync_input(games: [game_input(lifecycle: "in_progress")], at: later)
    )

    expect(result).to be_success
    change = Jumbotron::HistoricalChange.where(attribute_name: "lifecycle").order(:id).last
    expect(change).to be_present
    expect(change.new_value.to_s.delete_prefix('"').delete_suffix('"')).to eq("in_progress")
    expect(change.subject_type).to eq("Jumbotron::Game")
    expect(Jumbotron::Game.find(result.payload[:games].first.id).lifecycle).to eq("in_progress")
  end

  it "records schedule_group_id history when grouping changes" do
    apply_via_workflow!(sync_input)
    later = observed_at + 3.hours

    result = apply_via_workflow!(
      sync_input(
        games: [
          game_input(
            schedule_group: Jumbotron::Canonical::ScheduleGroupInput.new(
              kind: "week",
              number: 2,
              name: "Week 2"
            )
          )
        ],
        at: later
      )
    )

    expect(result).to be_success
    expect(Jumbotron::HistoricalChange.where(attribute_name: "schedule_group_id")).to be_present
  end

  it "rolls back the entire transaction on canonical mutation failure" do
    before_games = Jumbotron::Game.count
    before_batches = Jumbotron::ObservationBatch.count

    result = apply_via_workflow!(
      sync_input(games: [game_input(lifecycle: "not_a_lifecycle")])
    )

    expect(result).to be_failure
    expect(result.meta[:failure_class]).to eq("mutation")
    expect(Jumbotron::Game.count).to eq(before_games)
    expect(Jumbotron::ObservationBatch.count).to eq(before_batches)
  end

  it "rolls back canonical mutation when observation evidence fails" do
    allow(Jumbotron::Services::Canonical::RecordObservationEvidence).to receive(:call).and_return(
      CommandTower::Services::ServiceResult.failure(
        errors: [Jumbotron::Errors::Canonical::ObservationEvidenceFailedError.new]
      )
    )

    before_games = Jumbotron::Game.count
    result = apply_via_workflow!(sync_input)

    expect(result).to be_failure
    expect(result.meta[:failure_class]).to eq("mutation")
    expect(Jumbotron::Game.count).to eq(before_games)
  end

  it "allows optional venue" do
    result = apply_via_workflow!(sync_input(games: [game_input(venue: nil)]))

    expect(result).to be_success
    expect(result.payload[:games].first.venue_id).to be_nil
  end

  it "upserts standalone teams from SyncInput.teams" do
    teams = [
      Jumbotron::Canonical::TeamInput.new(
        provider_identities: [team_ref(99)],
        name: "Solo Team"
      )
    ]
    result = apply_via_workflow!(sync_input(games: [], teams: teams))

    expect(result).to be_success
    team = Jumbotron::Team.find(result.payload[:teams].first.id)
    expect(team.name).to eq("Solo Team")
    expect(team.observed_at).to eq(observed_at)
  end

  it "fails validation when the adapter is not registered" do
    orphan = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecUnregistered"
      end

      provider :espn
      sport "football"
      league "ghost"
      endpoint :teams,
               resource: Jumbotron::Providers::Espn::Resources::Teams,
               transformer: Jumbotron::Adapters::Espn::NflHelpers::Teams
    end
    stub_const("Jumbotron::Adapters::SpecUnregistered", orphan)

    result = described_class.call(
      adapter: orphan,
      endpoint: :teams,
      league_id: league.id
    )

    expect(result).to be_failure
    expect(result.meta[:failure_class]).to eq("validation")
    code = result.errors.first
    code = code[:code] if code.is_a?(Hash)
    code = code.code if code.respond_to?(:code)
    expect(code).to eq("adapter_not_registered")
  end

  it "classifies acquisition failures separately from mutation and leaves canonical truth unchanged" do
    before_games = Jumbotron::Game.count
    transport = Jumbotron::SpecSupport::FakeTransport.new do |_request|
      CommandTower::Clients::Transport::Response.build(
        status: 500,
        body: '{"message":"boom"}',
        duration_ms: 1
      )
    end
    Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport))

    result = described_class.call(
      adapter: Jumbotron::Adapters::Espn::Nfl,
      endpoint: :scoreboard,
      league_id: league.id
    )

    expect(result).to be_failure
    expect(result.meta[:failure_class]).to eq("acquisition")
    expect(Jumbotron::Game.count).to eq(before_games)
  end

  it "does not start a canonical transaction when transform fails" do
    before_games = Jumbotron::Game.count
    allow(Jumbotron::Services::Adapters::ValidateSyncRequest).to receive(:call).and_return(
      CommandTower::Services::ServiceResult.success(data: { league: league })
    )
    allow(Jumbotron::Services::Adapters::ExecuteEndpoint).to receive(:call).and_return(
      CommandTower::Services::ServiceResult.failure(
        errors: [Jumbotron::Errors::Adapters::NormalizationFailedError.new]
      )
    )

    result = described_class.call(
      adapter: Jumbotron::Adapters::Espn::Nfl,
      endpoint: :scoreboard,
      league_id: league.id
    )

    expect(result).to be_failure
    expect(result.meta[:failure_class]).to eq("normalization")
    expect(Jumbotron::Game.count).to eq(before_games)
  end

  it "works with a minimal test adapter reusing ESPN Resources and different sport/league" do
    adapter = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::Espn::SpecReuse"
      end

      register!
      provider :espn
      sport "football"
      league "college-football"
      endpoint :teams,
               resource: Jumbotron::Providers::Espn::Resources::Teams,
               transformer: Jumbotron::Adapters::Espn::NflHelpers::Teams
    end
    stub_const("Jumbotron::Adapters::Espn::SpecReuse", adapter)

    transport = seed_transport!(fixture_root.join("teams.json").read)

    result = described_class.call(
      adapter: adapter,
      endpoint: :teams,
      league_id: league.id,
      observed_at: observed_at
    )

    expect(result).to be_success
    expect(transport.calls.first.url).to include("football/college-football/teams")
  ensure
    Jumbotron::Adapters::Registry.reset!
    Jumbotron::Adapters::Espn::Nfl.register!
  end
end
