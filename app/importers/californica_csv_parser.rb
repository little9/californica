# frozen_string_literal: true

class CalifornicaCsvParser < Darlingtonia::CsvParser
  ##
  # @!attribute [rw] error_stream
  #   @return [#<<]
  # @!attribute [rw] info_stream
  #   @return [#<<]
  attr_accessor :error_stream, :info_stream

  ##
  # @todo should error_stream and info_stream be moved to the base
  #   `Darlingtonia::Parser`?
  #
  # @param [#<<] error_stream
  # @param [#<<] info_stream
  def initialize(file:,
                 error_stream: Darlingtonia.config.default_error_stream,
                 info_stream:  Darlingtonia.config.default_info_stream,
                 **opts)
    self.error_stream = error_stream
    self.info_stream  = info_stream

    self.validators = [
      Darlingtonia::CsvFormatValidator.new(error_stream: error_stream),
      Darlingtonia::TitleValidator.new(error_stream: error_stream),
      RightsStatementValidator.new(error_stream: error_stream)
    ]

    super
  end

  # Skip this number of records before starting the ingest process. Default is 0.
  # Useful for re-starting a failed ingest without having to blow everything away.
  def skip
    return 0 unless ENV['SKIP']
    ENV['SKIP'].to_s.to_i
  end

  def records
    return enum_for(:records) unless block_given?
    file.rewind
    # use the CalifornicaMapper
    CSV.parse(file.read, headers: true).each_with_index do |row, index|
      next unless index >= skip
      next if row.to_h.values.all?(&:nil?)
      yield Darlingtonia::InputRecord.from(metadata: row, mapper: CalifornicaMapper.new)
    end
  rescue CSV::MalformedCSVError
    # error reporting for this case is handled by validation
    []
  end
end
