# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module Teams
          class Get
            def self.call(payload)
              Support.ensure_hash!(payload, label: "teams")

              teams_raw = extract_team_entries(payload)
              teams_raw.each_with_index.map do |entry, index|
                team_payload = entry.is_a?(Hash) ? (entry["team"] || entry) : entry
                Team.call(team_payload)
              rescue CommandTower::Clients::Errors::DeserializationError => e
                raise CommandTower::Deserializers::Clients::Errors.prefix(e, "teams[#{index}]")
              end
            end

            def self.extract_team_entries(payload)
              sports = Support.payload.fetch(payload, "sports")
              if sports.equal?(Support.missing) || !sports.is_a?(Array) || sports.empty?
                raise CommandTower::Clients::Errors::DeserializationError.new(
                  message: "sports[0] is required",
                  details: {
                    path: "sports",
                    expected: "Array",
                    actual: sports.equal?(Support.missing) ? "missing" : sports.class.name,
                    rule: "required",
                    messages: ["sports[0] is required"]
                  }
                )
              end

              sport = sports.first
              Support.ensure_hash!(sport, label: "sports[0]")
              leagues = Support.payload.fetch(sport, "leagues")
              if leagues.equal?(Support.missing) || !leagues.is_a?(Array) || leagues.empty?
                raise CommandTower::Clients::Errors::DeserializationError.new(
                  message: "sports[0].leagues[0] is required",
                  details: {
                    path: "sports[0].leagues",
                    expected: "Array",
                    actual: leagues.equal?(Support.missing) ? "missing" : leagues.class.name,
                    rule: "required",
                    messages: ["sports[0].leagues[0] is required"]
                  }
                )
              end

              league = leagues.first
              Support.ensure_hash!(league, label: "sports[0].leagues[0]")
              teams = Support.payload.fetch(league, "teams")
              if teams.equal?(Support.missing) || !teams.is_a?(Array)
                raise CommandTower::Clients::Errors::DeserializationError.new(
                  message: "sports[0].leagues[0].teams is required",
                  details: {
                    path: "sports[0].leagues[0].teams",
                    expected: "Array",
                    actual: teams.equal?(Support.missing) ? "missing" : teams.class.name,
                    rule: "required",
                    messages: ["sports[0].leagues[0].teams is required"]
                  }
                )
              end

              teams
            end
            private_class_method :extract_team_entries
          end
        end
      end
    end
  end
end
