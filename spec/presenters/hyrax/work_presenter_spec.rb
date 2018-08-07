# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Work`
require 'rails_helper'

RSpec.describe Hyrax::WorkPresenter, type: :presenter do
  subject(:presenter) { described_class.new(document, ability, request) }
  let(:ability)       { nil }
  let(:document)      { SolrDocument.new(work.to_solr) }
  let(:request)       { instance_double('Rack::Request', host: 'example.com') }
  let(:work)          { Work.create(title: ['foo title']) }

  describe '#export_as_ttl' do
    let(:expected_fields) do
      [:depositor, :title, :date_uploaded, :resource_type, :creator,
       :contributor, :description, :keyword, :license, :rights_statement,
       :publisher, :date_created, :subject, :language]
    end

    let(:properties) { work.class.properties }

    it 'has expected predicates' do
      predicates =
        expected_fields.map { |f| properties[f.to_s].predicate.to_base }

      expect(presenter.export_as_ttl).to include(*predicates)
    end
  end
end
