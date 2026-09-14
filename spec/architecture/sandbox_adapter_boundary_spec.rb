# frozen_string_literal: true

RSpec.describe "Sandbox adapter boundary" do
  let(:root) { Jumbotron::Engine.root }
  let(:sandbox_sources) do
    Dir[root.join("app/{adapters,providers}/**/sandbox/**/*.rb")].map { |path| File.read(path) }.join("\n")
  end
  let(:sandbox_workflows) do
    Dir[root.join("app/workflows/jumbotron/workflows/sandbox/**/*.rb")]
      .map { |path| File.read(path) }
      .join("\n")
  end

  it "keeps sandbox acquisition in-process and outside the ESPN client" do
    expect(sandbox_sources).not_to include("Jumbotron::Clients.espn")
    expect(sandbox_sources).not_to include("Providers::Espn")
    expect(sandbox_sources).not_to include("Clients::Espn")
  end

  it "exposes only structured JT-3 sandbox control-plane operations" do
    expect(defined?(Jumbotron::Workflows::Sandbox::RegisterProjectionWorkflow)).not_to be_nil
    expect(defined?(Jumbotron::Workflows::Sandbox::ResetProjectionWorkflow)).not_to be_nil
    expect(Jumbotron::Client.public_instance_methods(false)).to contain_exactly(
      :schedule,
      :schedule_groups,
      :game,
      :games,
      :consensus,
      :current_lines,
      :sandbox_projection,
      :register_sandbox_projection,
      :reset_sandbox_projection
    )
  end

  it "does not expose a sandbox HTTP surface in JT-3" do
    expect(Dir[root.join("app/controllers/**/*sandbox*")]).to be_empty
    expect(root.join("config/routes.rb")).not_to exist
  end

  it "keeps Reset free of workflow nesting and alternate canonical writers" do
    expect(sandbox_workflows).not_to match(/Workflows::.*Workflow\.call/)
    expect(sandbox_workflows).not_to include("ApplySyncInput")
    expect(sandbox_workflows).not_to include("SharedSequence")
  end
end
