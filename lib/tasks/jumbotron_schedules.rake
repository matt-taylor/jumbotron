# frozen_string_literal: true

namespace :jumbotron do
  namespace :schedules do
    desc "Materialize Jumbotron recurring schedules into the host scheduler"
    task materialize: :environment do
      Jumbotron::Scheduling::Materializer.call(
        solid_queue_path: ENV.fetch("JUMBOTRON_SOLID_QUEUE_RECURRING", nil)
      )
    end
  end
end
