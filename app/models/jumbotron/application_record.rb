# frozen_string_literal: true

module Jumbotron
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = "jumbotron_"
  end
end
