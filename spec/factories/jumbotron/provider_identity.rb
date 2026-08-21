# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_provider_identity, class: "Jumbotron::ProviderIdentity" do
    association :target, factory: :jumbotron_sport
    provider { "espn" }
    object_namespace { "sport" }
    sequence(:provider_id) { |n| "ext-#{n}" }
  end
end
