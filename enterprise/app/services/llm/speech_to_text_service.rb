# Blob-in, text-out audio transcription shared by voice-note attachments
# (Messages::AudioTranscriptionService) and voice-call recordings
# (Voice::CallTranscriptionService).
class Llm::SpeechToTextService
  include Integrations::LlmInstrumentation

  # OpenAI's transcription endpoint hard limit is 25 MB *decimal* (25_000_000), not
  # binary (25.megabytes = 26_214_400) — using the binary form leaks the 25.0–26.2 MB
  # range to the API as 413s. Long audio (~70+ min Opus) keeps the source audio but
  # skips transcription.
  BYTE_LIMIT = 25_000_000

  attr_reader :blob, :account, :route

  def self.available_for?(account)
    return false unless account.feature_enabled?('tekomi_integration')
    return false if account.audio_transcriptions.blank?

    account.usage_limits[:tekomi][:responses][:current_available].positive?
  end

  def self.too_large?(blob)
    blob.present? && blob.byte_size > BYTE_LIMIT
  end

  def initialize(blob:, account:)
    @blob = blob
    @account = account
    @route = Llm::FeatureRouter.resolve(feature: 'audio_transcription')
  end

  def perform
    temp_file_path = fetch_audio_file
    transcribed_text = instrument_audio_transcription(instrumentation_params(temp_file_path)) do
      # temperature: 0.0 minimises hallucinations on silence / near-silent
      # audio; non-zero values trigger spiraling repeats — well-documented
      # behaviour across OpenAI transcription models.
      RubyLLM.transcribe(temp_file_path, model: route[:model], provider: route[:provider], assume_model_exists: true, temperature: 0.0).text
    end

    account.increment_response_usage if transcribed_text.present?
    transcribed_text
  ensure
    FileUtils.rm_f(temp_file_path) if temp_file_path.present?
  end

  private

  def fetch_audio_file
    temp_dir = Rails.root.join('tmp/uploads/audio-transcriptions')
    FileUtils.mkdir_p(temp_dir)
    temp_file_name = "#{blob.key}-#{blob.filename}"

    if blob.filename.extension_without_delimiter.blank?
      extension = extension_from_content_type(blob.content_type)
      temp_file_name = "#{temp_file_name}.#{extension}" if extension.present?
    end

    temp_file_path = File.join(temp_dir, temp_file_name)

    File.open(temp_file_path, 'wb') do |file|
      blob.open do |blob_file|
        IO.copy_stream(blob_file, file)
      end
    end

    temp_file_path
  end

  def extension_from_content_type(content_type)
    subtype = content_type.to_s.downcase.split(';').first.to_s.split('/').last.to_s
    return if subtype.blank?

    {
      'x-m4a' => 'm4a',
      'x-wav' => 'wav',
      'x-mp3' => 'mp3'
    }.fetch(subtype, subtype)
  end

  def instrumentation_params(file_path)
    {
      span_name: 'llm.messages.audio_transcription',
      model: route[:model],
      account_id: account&.id,
      feature_name: 'audio_transcription',
      file_path: file_path
    }
  end
end
