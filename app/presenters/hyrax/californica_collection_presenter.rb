# frozen_string_literal: true
module Hyrax
  class CalifornicaCollectionPresenter < Hyrax::CollectionPresenter
    # Terms is the list of fields displayed by
    # app/views/collections/_show_descriptions.html.erb
    def self.terms
      [
        :total_items, :size, :resource_type, :creator, :contributor,
        :keyword, :license, :publisher, :date_created, :subject,
        :language, :identifier, :based_near, :related_url,
        :extent, :caption,
        :dimensions, :funding_note, :genre,
        :latitude, :longitude,
        :local_identifier, :medium,
        :named_subject, :normalized_date,
        :repository, :location,
        :rights_country, :rights_holder, :photographer
      ]
    end
  end
end
