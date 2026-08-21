# frozen_string_literal: true

# Live ESPN full-season discovery contract smoke (not part of make test).
# Usage (from jumbotron/):
#   docker-compose run --rm -e RAILS_ENV=development engine \
#     bundle exec rails runner script/espn_full_season_discovery_smoke.rb
#
# Durable because ESPN year-only boards silently cap at ~100 events and honor
# `seasontype` (not `season_type`) together with `week`. Re-run when ESPN query
# behavior is suspected to have changed.

require "json"
require "net/http"
require "time"
require "uri"

module EspnFullSeasonDiscoverySmoke
  module_function

  SPORT = "football"
  LEAGUE = "nfl"
  YEARS = [2025, 2026].freeze

  def run!
    puts("=" * 80)
    puts("ESPN full-season discovery smoke — #{Time.now.utc.iso8601}")
    puts("Base: #{Jumbotron::Clients::Espn::DEFAULT_BASE_URL}")
    puts("=" * 80)

    YEARS.each do |year|
      puts("\n## Season year #{year}")
      a = candidate_a(year)
      print_row("A year-only dates=#{year}", a)
      b = candidate_b(year)
      print_row("B phase-only unique union", b)
      c = candidate_c(year)
      print_row("C calendar seasontype+week", c)
      puts("selected=#{selected(a, b, c)}")
    end
  end

  def candidate_a(year)
    summarize(raw_board(dates: year).merge(query: { dates: year }))
  end

  def candidate_b(year)
    rows = [1, 2, 3].map { |season_type| raw_board(dates: year, seasontype: season_type) }
    ids = rows.flat_map { |row| row[:ids] }
    {
      query: rows.map { |row| row[:query] },
      event_count: ids.size,
      unique_event_count: ids.uniq.size,
      overlap: (rows[0][:ids] & rows[1][:ids]).size,
      season_types: rows.flat_map { |row| row[:season_types] }.uniq.sort,
      weeks: rows.flat_map { |row| row[:weeks] }.uniq.sort,
      future_games: rows.sum { |row| row[:future_games] },
      pagination: rows.first[:pagination],
      truncated: true
    }
  end

  def candidate_c(year)
    seed = fetch_json(dates: year, seasontype: 2)
    requests = calendar_requests(year, seed)
    ids = []
    types = []
    weeks = []
    future = 0
    earliest = nil
    latest = nil
    requests.each do |query|
      row = raw_board(**query)
      ids.concat(row[:ids])
      types.concat(row[:season_types])
      weeks.concat(row[:weeks])
      future += row[:future_games]
      earliest = [earliest, row[:earliest]].compact.min
      latest = [latest, row[:latest]].compact.max
    end
    {
      query: "dates+seasontype+week from leagues[].calendar (#{requests.size} requests)",
      event_count: ids.size,
      unique_event_count: ids.uniq.size,
      season_types: types.uniq.sort,
      weeks: weeks.uniq.sort,
      earliest: earliest,
      latest: latest,
      future_games: future,
      request_count: requests.size,
      truncated: ids.uniq.size < 250
    }
  end

  def calendar_requests(year, payload)
    Array(payload.dig("leagues", 0, "calendar")).flat_map do |entry|
      next [] unless entry.is_a?(Hash)

      season_type = entry["value"].to_i
      next [] unless [1, 2, 3].include?(season_type)

      Array(entry["entries"]).filter_map do |week|
        number = week.is_a?(Hash) ? week["value"].to_i : 0
        next unless number.positive?

        { dates: year, seasontype: season_type, week: number }
      end
    end
  end

  def raw_board(**query)
    payload = fetch_json(**query)
    events = Array(payload["events"])
    dates = events.filter_map { |event| parse_time(event["date"]) }
    {
      query: query,
      ids: events.map { |event| event["id"] },
      event_count: events.size,
      unique_event_count: events.map { |event| event["id"] }.uniq.size,
      season_types: events.filter_map { |event| event.dig("season", "type") }.uniq.sort,
      weeks: events.filter_map { |event| event.dig("week", "number") }.uniq.sort,
      earliest: dates.min&.utc&.iso8601,
      latest: dates.max&.utc&.iso8601,
      future_games: dates.count { |time| time > Time.now.utc },
      pagination: payload.slice("pageIndex", "pageCount", "pageSize", "resultsCount", "resultsLimit"),
      truncated: events.size == 100
    }
  end

  def summarize(row)
    row
  end

  def selected(candidate_a, candidate_b, candidate_c)
    return "A" if complete?(candidate_a)
    return "B" if complete?(candidate_b)
    return "C" if complete?(candidate_c)

    "none"
  end

  def complete?(row)
    Array(row[:season_types]).include?(2) && row[:unique_event_count].to_i >= 250 && !row[:truncated]
  end

  def fetch_json(**query)
    uri = URI.join("#{Jumbotron::Clients::Espn::DEFAULT_BASE_URL}/", "#{SPORT}/#{LEAGUE}/scoreboard")
    uri.query = URI.encode_www_form(query.compact)
    response = Net::HTTP.get_response(uri)
    raise "HTTP #{response.code} for #{uri}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def parse_time(value)
    return if value.blank?

    Time.iso8601(value.to_s)
  rescue ArgumentError
    Time.parse(value.to_s)
  end

  def print_row(title, row)
    puts("-" * 80)
    puts(title)
    puts("  request: #{row[:query].inspect}")
    puts("  event_count: #{row[:event_count]} unique=#{row[:unique_event_count]} overlap=#{row[:overlap]}")
    puts("  season_types: #{row[:season_types].inspect}")
    puts("  weeks: #{Array(row[:weeks]).inspect}")
    puts("  date_range: #{row[:earliest]} .. #{row[:latest]}")
    puts("  future_games: #{row[:future_games]}")
    puts("  pagination: #{row[:pagination].inspect}")
    puts("  truncated?: #{row[:truncated]}")
    puts("  complete?: #{complete?(row)}")
    puts("  request_count: #{row[:request_count]}") if row[:request_count]
  end
end

EspnFullSeasonDiscoverySmoke.run!
