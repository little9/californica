# frozen_string_literal: true

class CalifornicaMapper < Darlingtonia::HashMapper
  attr_reader :missing_file_log

  CALIFORNICA_TERMS_MAP = {
    identifier: "Item Ark",
    title: "Title",
    subject: "Subject",
    description: "Description.note",
    resource_type: "Type.typeOfResource",
    latitude: "Description.latitude",
    longitude: "Description.longitude",
    extent: "Format.extent",
    local_identifier: "Alternate Identifier.local",
    date_created: "Date.creation",
    caption: "Description.caption",
    dimensions: "Format.dimensions",
    funding_note: "Description.fundingNote",
    genre: "Type.genre",
    rights_holder: "Rights.rightsHolderContact",
    rights_country: "Rights.countryCreation",
    rights_statement: "Rights.copyrightStatus",
    medium: "Format.medium",
    normalized_date: "Date.normalized",
    publisher: "Publisher.publisherName",
    repository: "Name.repository",
    location: "Coverage.geographic",
    named_subject: "Name.subject",
    language: "Language",
    photographer: "Name.photographer",
    dlcs_collection_name: "Relation.isPartOf"
  }.freeze

  DELIMITER = '|~|'

  def initialize
    @missing_file_log = ENV['MISSING_FILE_LOG'] || "#{::Rails.root}/log/missing_files_#{Rails.env}"
    super
  end

  def fields
    CALIFORNICA_TERMS_MAP.keys + [:remote_files, :visibility]
  end

  ##
  # Take a filename and:
  # 1) Check that it exists. Log it to a missing files log if it doesn't.
  # 2) Turn the filename into a file:// url
  # 3) Pass it to the actor stack in the remote_files param. This means that
  # it will be processed by the CreateWithRemoteFilesActor
  # Using the remote_files param to ingest local files is misleading.
  # However, it lets us fetch the file from disk in a background job
  # instead of creating a Hyrax::UploadedFile object while the CSV is
  # being parsed, which gives us a performance advantage.
  def remote_files
    if metadata['masterImageName'].nil?
      File.open(@missing_file_log, 'a') { |file| file.puts "Work #{map_field(:identifier)} is missing a filename" }
      return []
    end
    file_name = file_uri_base_path.join(metadata['masterImageName']).to_s
    file_exists = File.exist?(file_name)
    return_value = []
    if file_exists
      return_value = [{ url: file_uri_for(name: metadata['masterImageName']) }]
    else
      File.open(@missing_file_log, 'a') { |file| file.puts "Work #{map_field(:identifier)} has an invalid file: #{file_name} not found" }
    end
    return_value
  end

  def visibility
    Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
  end

  # To avoid having to normalize data before import,
  # if the collection is LADNN, hard-code the extent. (Story #111)
  def extent
    if ladnn?
      ['1 photograph']
    else
      map_field(:extent)
    end
  end

  # Hard-code repository for LADNN collection. Story #121
  def repository
    if ladnn?
      ['University of California, Los Angeles. Library. Department of Special Collections']
    else
      map_field(:repository)
    end
  end

  # Normalize subject to remove MaRC codes (e.g., $z separators)
  # Replace subject marc codes with double dashes with no surrounding spaces
  def subject
    map_field(:subject)&.map { |a| a.gsub(/ \$[a-z] /, '--') }
  end

  # Normalize named subject to remove MaRC codes (e.g., $d separators)
  # Replace named subject marc codes and their surrounding spaces with a single space
  def named_subject
    map_field(:named_subject)&.map { |a| a.gsub(/ \$[a-z] /, ' ') }
  end

  # Hard-code language for LADNN collection. Story #48
  def language
    if ladnn?
      ['No linguistic content']
    else
      map_field(:language)
    end
  end

  def ladnn?
    metadata['Project Name'] == 'Los Angeles Daily News Negatives'
  end

  # The CSV file contains the label, so we'll find the
  # corresponding ID to store on the work record.
  # If the term isn't found in
  # config/authorities/rights_statements.yml
  # just return the value from the CSV file.  If it is
  # not a valid value, it will eventually be rejected
  # by the RightsStatementValidator.
  def rights_statement
    return unless metadata['Rights.copyrightStatus']
    rights_term = Qa::Authorities::Local.subauthority_for('rights_statements').all.find { |h| h[:label] == metadata['Rights.copyrightStatus'] }
    rights_term.blank? ? metadata['Rights.copyrightStatus'] : rights_term[:id]
  end

  def map_field(name)
    return unless CALIFORNICA_TERMS_MAP.keys.include?(name)

    metadata[CALIFORNICA_TERMS_MAP[name]]&.split(DELIMITER)
  end

  private

    def file_uri_for(name:)
      uri      = URI('file:///')
      uri.path = file_uri_base_path.join(name).to_s
      uri.to_s
    end

    def file_uri_base_path
      Pathname.new(ENV['IMPORT_FILE_PATH'] || '/opt/data')
    end
end
