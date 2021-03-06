# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CalifornicaMapper do
  subject(:mapper) { described_class.new }

  let(:metadata) do
    { "Item Ark" => "21198/zz0002nq4w",
      "Title" => "Protesters with signs in gallery of Los Angeles County Supervisors " \
      "hearing over eminent domain for construction of Harbor Freeway, Calif., 1947",
      "Type.typeOfResource" => "still image",
      "Subject" => "Express highways--California--Los Angeles County--Design and construction|~|" \
      "Eminent domain--California--Los Angeles|~|Demonstrations--California--Los Angeles County|~|" \
      "Transportation|~|Government|~|Activism|~|Interstate 10",
      "Publisher.publisherName" => "Los Angeles Daily News",
      "Format.medium" => "1 photograph",
      "Rights.countryCreation" => "US",
      "Name.repository" => "University of California, Los Angeles. $b Library Special Collections",
      "Description.caption" => "This example does not have a caption.",
      "masterImageName" => "clusc_1_1_00010432a.tif",
      "Coverage.geographic" => "Los Angeles (Calif.)",
      "Name.subject" => "Los Angeles County (Calif.). $b Board of Supervisors",
      "Language" => "English",
      "Relation.isPartOf" => "Connell (Will) Papers, 1928-1961" }
  end

  before { mapper.metadata = metadata }
  after { File.delete(ENV['MISSING_FILE_LOG']) if File.exist?(ENV['MISSING_FILE_LOG']) }

  it "maps the required title field" do
    expect(mapper.map_field(:title))
      .to contain_exactly("Protesters with signs in gallery of Los Angeles County Supervisors " \
                          "hearing over eminent domain for construction of Harbor Freeway, Calif., 1947")
  end

  it "maps the required identifier field" do
    expect(mapper.map_field(:identifier)).to contain_exactly('21198/zz0002nq4w')
  end

  it "maps the collection (relation.isPartOf) field" do
    expect(mapper.map_field(:dlcs_collection_name)).to contain_exactly("Connell (Will) Papers, 1928-1961")
  end

  it "maps remote_files" do
    expect(mapper.remote_files)
      .to contain_exactly(url: match(/clusc_1_1_00010432a\.tif/))
  end

  it "maps visibility to open" do
    expect(mapper.visibility)
      .to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
  end

  context 'with a blank filename' do
    let(:metadata) do
      { "Item Ark" => "21198/zz0002nq4w",
        "Title" => "Protesters with signs in gallery of Los Angeles County Supervisors " \
        "hearing over eminent domain for construction of Harbor Freeway, Calif., 1947",
        "Type.typeOfResource" => "still image",
        "Subject" => "Express highways--California--Los Angeles County--Design and construction|~|" \
        "Eminent domain--California--Los Angeles|~|Demonstrations--California--Los Angeles County|~|" \
        "Transportation|~|Government|~|Activism|~|Interstate 10",
        "Publisher.publisherName" => "Los Angeles Daily News",
        "Format.medium" => "1 photograph",
        "Rights.countryCreation" => "US",
        "Name.repository" => "University of California, Los Angeles. $b Library Special Collections",
        "Description.caption" => "This example does not have a caption.",
        # "masterImageName" => nil,
        "Coverage.geographic" => "Los Angeles (Calif.)",
        "Name.subject" => "Los Angeles County (Calif.). $b Board of Supervisors",
        "Photographer" => "Ansel Adams",
        "Language" => "English" }
    end
    it "does not throw an error if masterImageName is empty" do
      expect(mapper.remote_files).to eq []
    end
  end

  describe '#fields' do
    it 'has expected fields' do
      expect(mapper.fields).to include(
        :visibility, :identifier, :title, :subject,
        :resource_type, :description, :latitude,
        :longitude, :extent, :local_identifier,
        :date_created, :caption, :dimensions, :rights_country,
        :funding_note, :genre, :rights_holder,
        :medium, :normalized_date, :location, :publisher, :photographer, :remote_files
      )
    end
  end

  describe '#extent' do
    context 'when collection is LADNN' do
      let(:metadata) do
        { "Project Name" => "Los Angeles Daily News Negatives",
          "Format.extent" => "This value is ignored" }
      end

      it 'hard codes the extent field' do
        expect(mapper.extent).to eq ['1 photograph']
      end
    end

    context 'when it doesn\'t require special handling' do
      let(:metadata) do
        { "Project Name" => "Another collection",
          "Format.extent" => "Ext 1|~|Ext 2" }
      end

      it 'reads the value from the metadata' do
        expect(mapper.extent).to contain_exactly("Ext 1", "Ext 2")
      end
    end
  end

  describe '#repository' do
    context 'when collection is LADNN' do
      let(:metadata) do
        { "Project Name" => "Los Angeles Daily News Negatives",
          "Name.repository" => "This value is ignored" }
      end

      it 'hard codes the repository field' do
        expect(mapper.repository).to eq ['University of California, Los Angeles. Library. Department of Special Collections']
      end
    end

    context 'when it doesn\'t require special handling' do
      let(:metadata) do
        { "Project Name" => "Another collection",
          "Name.repository" => "Repo 1|~|Repo 2" }
      end

      it 'reads the value from the metadata' do
        expect(mapper.repository).to contain_exactly("Repo 1", "Repo 2")
      end
    end
  end

  describe '#subject' do
    context 'when it contains MaRC separators' do
      let(:metadata) do
        { "Project Name" => "Los Angeles Daily News Negatives",
          "Name.repository" => "Repo 1|~|Repo 2",
          "Subject" => "Wrestlers $z California $z Los Angeles|~|Los Angeles County (Calif.). $b Board of Supervisors" }
      end
      it 'replaces them with double dashes' do
        expect(mapper.subject).to contain_exactly("Wrestlers--California--Los Angeles", "Los Angeles County (Calif.).--Board of Supervisors")
      end
    end
  end

  describe '#named_subject' do
    context 'when it contains MaRC separators' do
      let(:metadata) do
        { "Project Name" => "Los Angeles Daily News Negatives",
          "Name.subject" => "Nagurski, Bronko, $d 1908-1990|~|Olympic Games $n (8th : $d 1924 : $c Paris, France)" }
      end
      it 'removes them and their surrounding spaces' do
        expect(mapper.named_subject).to contain_exactly("Nagurski, Bronko, 1908-1990", "Olympic Games (8th : 1924 : Paris, France)")
      end
    end
  end

  context "UCLA has not agreed to use rightsstatement.org" do
    describe '#rights_statement' do
      context 'when the field is blank' do
        # No value for "Rights.copyrightStatus"
        let(:metadata) { { 'Title' => 'A title' } }

        it 'returns nil' do
          expect(mapper.rights_statement).to eq nil
        end
      end

      context 'with a valid value' do
        let(:metadata) do
          { 'Title' => 'A title',
            'Rights.copyrightStatus' => 'copyrighted' }
        end

        it 'finds the correct ID for the given value' do
          expect(mapper.rights_statement).to eq "http://vocabs.library.ucla.edu/rights/copyrighted"
        end
      end

      context 'with an invalid value' do
        let(:metadata) do
          { 'Title' => 'A title',
            'Rights.copyrightStatus' => 'something invalid' }
        end

        it 'returns the same value' do
          expect(mapper.rights_statement).to eq 'something invalid'
        end
      end
    end
  end
end
