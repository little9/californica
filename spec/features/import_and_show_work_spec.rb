# frozen_string_literal: true
require 'rails_helper'
include Warden::Test::Helpers

RSpec.feature 'Import and Display a Work', :clean, js: false do
  subject(:importer) { CalifornicaImporter.new(file, collection_id: collection.id, depositor_id: user.user_key) }
  let(:file)       { File.open(csv_file) }
  let(:csv_file)   { File.join(fixture_path, 'coordinates_example.csv') }
  let(:user)       { FactoryBot.create(:user) }
  let(:collection) { FactoryBot.create(:collection_lw, user: user) }

  # Cleanup log files after each test run
  after do
    File.delete(importer.ingest_log_filename) if File.exist? importer.ingest_log_filename
    File.delete(importer.error_log_filename) if File.exist? importer.error_log_filename
    File.delete(ENV['MISSING_FILE_LOG']) if File.exist?(ENV['MISSING_FILE_LOG'])
  end

  context "importing the same object twice" do
    let(:first_csv_file)   { File.open(File.join(fixture_path, 'coordinates_example.csv')) }
    let(:second_csv_file)  { File.open(File.join(fixture_path, 'coordinates_example_update.csv')) }
    let(:first_importer) { CalifornicaImporter.new(first_csv_file, collection_id: collection.id, depositor_id: user.user_key) }
    let(:second_importer) { CalifornicaImporter.new(second_csv_file, collection_id: collection.id, depositor_id: user.user_key) }
    after do
      first_csv_file.close
      second_csv_file.close
    end
    it 'updates existing records if the ARK matches' do
      first_importer.import
      work = Work.last
      expect(work.funding_note.first).to eq "Fake Funding Note"
      expect(work.medium.first).to eq "Fake Medium"
      second_importer.import
      work.reload
      expect(work.funding_note.first).to eq "Better Funding Note"
      expect(work.medium).to eq []
    end
  end

  context "importing a CSV" do
    it "adds works to the specified collection" do
      expect(collection.title.first).to match(/Collection Title/)
      importer.import
      work = Work.last
      expect(work.member_of_collections).to eq [collection]
    end
    it "displays expected fields on show work page" do
      importer.import
      work = Work.last
      visit("/concern/works/#{work.id}")
      expect(page).to have_content "Communion at Plaza Church, Los Angeles, 1942-1952" # title
      expect(page).to have_content "13030/hb338nb26f" # identifier
      expect(page).to have_content "Guadalupe, Our Lady of" # subject
      expect(page).to have_content "Churches--California--Los Angeles" # subject
      expect(page).to have_content "Historic buildings--California--Los Angeles" # $subject: $z has been replaced with --
      expect(page).to have_content "still image" # resource_type
      expect(page).to have_content "copyrighted" # rights_statement
      expect(page).not_to have_css('li.attribute-rights_statement/a') # Rights statement should not link anywhere
      expect(page).to have_content "news photographs" # genre
      expect(page).to have_content "Plaza Church (Los Angeles, Calif.)" # named_subject
      expect(page).to have_content "University of California, Los Angeles. Library. Department of Special Collections" # repository
      expect(page).to have_content "Los Angeles Daily News" # publisher
      expect(page).to have_content "US" # rights_country
      expect(page).to have_content "UCLA Charles E. Young Research Library Department of Special Collections, A1713 Young Research Library, Box 951575, Los Angeles, CA 90095-1575. E-mail: spec-coll@library.ucla.edu. Phone: (310)825-4988" # rights_holder
      expect(page).to have_content "1942/1952" # normalized_date
      expect(page).to have_content "uclamss_1387_b112_40911-1" # local_identifier
      expect(page).to have_content "[between 1942-1947]" # date_created
      expect(page).to have_content "1 photograph" # extent
      expect(page).to have_content "Fake Medium" # medium
      expect(page).to have_content "200x200" # dimensions
      expect(page).to have_content "Fake Funding Note" # funding_note
      expect(page).to have_content "Fake Caption" # caption
      expect(page).to have_content "No linguistic content" # language
      expect(page).to have_content "Famous Photographer" # photographer
      expect(page).to have_content "34.05707, -118.239577" # geographic_coordinates, a.k.a. latitude and longitude
      expect(page).to have_content "Los Angeles Daily News Negatives. Department of Special Collections, Charles E. Young Research Library, University of California at Los Angeles." # relation.isPartOf
    end
    it "displays expected fields on search results page" do
      importer.import
      work = Work.last
      visit("catalog?search_field=all_fields&q=")
      expect(page).to have_content work.title.first
      expect(page).to have_content work.description.first
      expect(page).to have_content work.normalized_date.first
      expect(page).to have_content work.resource_type.first
    end
  end
  it "displays expected facets" do
    importer.import
    visit("/catalog?search_field=all_fields&q=")
    facet_headings = page.all(:css, 'h3.facet-field-heading/a').to_a.map(&:text)
    expect(facet_headings).to contain_exactly("Subject", "Resource type", "Genre", "Names", "Location", "Normalized Date", "Extent", "Medium", "Dimensions", "Language", "Collection")
  end
end
