class Tekomi::Llm::UpdateEmbeddingJob < ApplicationJob
  queue_as :low

  def perform(record, content)
    account_id = record.account_id
    embedding = Tekomi::Llm::EmbeddingService.new(account_id: account_id).get_embedding(content)
    record.update!(embedding: embedding)
  end
end
