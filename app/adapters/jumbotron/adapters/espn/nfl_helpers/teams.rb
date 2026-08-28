# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Espn
      module NflHelpers
        class Teams
          def self.call(teams, observed_at:)
            list = Array(teams)
            Canonical::SyncInput.new(
              observed_at: observed_at,
              games: [],
              teams: list.map { |team| transform_team(team) }
            )
          end

          def self.transform_team(team)
            raise TransformError, "team id is required" if team.id.nil? || team.id.to_s.empty?

            name = team.display_name.presence || team.name
            raise TransformError, "team name is required for #{team.id}" if name.nil? || name.to_s.empty?

            Canonical::TeamInput.new(
              provider_identities: [
                Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "team", id: team.id.to_s)
              ],
              name: name.to_s,
              nickname: TeamNickname.resolve(team)
            )
          end
          private_class_method :transform_team
        end
      end
    end
  end
end
