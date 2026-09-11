class Tekomi::Llm::PaginatedFaqGeneratorService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  # Default pages per chunk - easily configurable
  DEFAULT_PAGES_PER_CHUNK = 10
  MAX_ITERATIONS = 20 # Safety limit to prevent infinite loops

  attr_reader :total_pages_processed, :iterations_completed

  def initialize(document, options = {})
    super(feature: 'pdf_faq_generation')
    @document = document
    @language = options[:language] || 'english'
    @pages_per_chunk = options[:pages_per_chunk] || DEFAULT_PAGES_PER_CHUNK
    @max_pages = options[:max_pages] # Optional limit from UI
    @total_pages_processed = 0
    @iterations_completed = 0
  end

  def generate
    @document.pdf_file.blob.open { |pdf_file| generate_paginated_faqs(pdf_file.path) }
  end

  # Method to check if we should continue processing
  def should_continue_processing?(last_chunk_result)
    # Stop if we've hit the maximum iterations
    return false if @iterations_completed >= MAX_ITERATIONS

    # Stop if we've processed the maximum pages specified
    return false if @max_pages && @total_pages_processed >= @max_pages

    # Stop if the last chunk returned no FAQs (likely no more content)
    return false if last_chunk_result[:faqs].empty?

    # Stop if the LLM explicitly indicates no more content
    return false if last_chunk_result[:has_content] == false

    # Continue processing
    true
  end

  private

  def generate_paginated_faqs(pdf_path)
    all_faqs = []
    current_page = 1

    loop do
      end_page = calculate_end_page(current_page)
      chunk_result = process_chunk_and_update_state(pdf_path, current_page, end_page, all_faqs)

      break unless should_continue_processing?(chunk_result)

      current_page = end_page + 1
    end

    deduplicate_faqs(all_faqs)
  end

  def calculate_end_page(current_page)
    end_page = current_page + @pages_per_chunk - 1
    @max_pages && end_page > @max_pages ? @max_pages : end_page
  end

  def process_chunk_and_update_state(pdf_path, current_page, end_page, all_faqs)
    chunk_result = process_page_chunk(pdf_path, current_page, end_page)
    chunk_faqs = chunk_result[:faqs]

    all_faqs.concat(chunk_faqs)
    @total_pages_processed = end_page
    @iterations_completed += 1

    chunk_result
  end

  def process_page_chunk(pdf_path, start_page, end_page)
    prompt = page_chunk_prompt(start_page, end_page)

    response = instrument_llm_call(build_instrumentation_params(prompt, start_page, end_page)) do
      chat.with_params(response_format: { type: 'json_object' }).ask(prompt, with: pdf_path)
    end

    result = parse_chunk_response(response.content)
    { faqs: result['faqs'] || [], has_content: result['has_content'] != false }
  rescue RubyLLM::Error => e
    Rails.logger.error I18n.t('tekomi.documents.page_processing_error', start: start_page, end: end_page, error: e.message)
    { faqs: [], has_content: false }
  end

  def page_chunk_prompt(start_page, end_page)
    Tekomi::Llm::SystemPromptsService.paginated_faq_generator(start_page, end_page, @language)
  end

  def parse_chunk_response(content)
    return { 'faqs' => [], 'has_content' => false } if content.nil?

    JSON.parse(sanitize_json_response(content))
  rescue JSON::ParserError => e
    Rails.logger.error "Error parsing chunk response: #{e.message}"
    { 'faqs' => [], 'has_content' => false }
  end

  def deduplicate_faqs(faqs)
    # Remove exact duplicates
    unique_faqs = faqs.uniq { |faq| faq['question'].downcase.strip }

    # Remove similar questions
    final_faqs = []
    unique_faqs.each do |faq|
      similar_exists = final_faqs.any? do |existing|
        similarity_score(existing['question'], faq['question']) > 0.85
      end

      final_faqs << faq unless similar_exists
    end

    Rails.logger.info "Deduplication: #{faqs.size} → #{final_faqs.size} FAQs"
    final_faqs
  end

  def similarity_score(str1, str2)
    words1 = str1.downcase.split(/\W+/).reject(&:empty?)
    words2 = str2.downcase.split(/\W+/).reject(&:empty?)
    common_words = words1 & words2
    total_words = (words1 + words2).uniq.size
    return 0 if total_words.zero?

    common_words.size.to_f / total_words
  end

  def build_instrumentation_params(prompt, start_page, end_page)
    {
      span_name: 'llm.paginated_faq_generation',
      account_id: @document&.account_id,
      feature_name: 'paginated_faq_generation',
      model: @model,
      messages: [{ role: 'user', content: prompt }],
      metadata: document_metadata.merge(start_page: start_page, end_page: end_page, iteration: @iterations_completed + 1)
    }
  end

  def document_metadata
    @document&.to_llm_metadata || {}
  end
end
