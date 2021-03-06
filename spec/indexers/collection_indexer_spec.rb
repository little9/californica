# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ::CollectionIndexer do
  let(:solr_document) { indexer.generate_solr_document }
  let(:indexer) { described_class.new(collection) }
  let(:collection) { ::Collection.new(attributes) }

  describe 'indexing ARK and identifier fields' do
    let(:attributes) { { identifier: ['ark:/123/456'] } }

    it 'add the fields to the solr document' do
      expect(solr_document['ark_ssi']).to eq 'ark:/123/456'
      expect(solr_document['identifier_ssim']).to eq ['ark:/123/456']
    end
  end
end
