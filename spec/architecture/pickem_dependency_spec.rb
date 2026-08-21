# frozen_string_literal: true

RSpec.describe "Jumbotron must not depend on Pick'em" do
  def pickem_references_in(relative_path)
    contents = File.read(Jumbotron::Engine.root.join(relative_path))
    contents.scan(%r{PickEm|pick_em|pickem/|/pickem|\.\./pickem})
  end

  let(:scanned_paths) do
    Dir.chdir(Jumbotron::Engine.root) do
      Dir.glob("{lib,app,db}/**/*").select { |path| File.file?(path) } +
        Dir.glob("*.gemspec") +
        ["Gemfile"]
    end
  end

  it "does not reference Pick'em from Engine package files" do
    violations = scanned_paths.filter_map do |relative_path|
      matches = pickem_references_in(relative_path)
      next if matches.empty?

      "#{relative_path}: #{matches.uniq.join(', ')}"
    end

    expect(violations).to eq([])
  end
end
