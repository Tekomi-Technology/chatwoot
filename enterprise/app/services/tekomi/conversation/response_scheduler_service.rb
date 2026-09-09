class Tekomi::Conversation::ResponseSchedulerService
  MAX_ATTACHMENT_WAIT_SECONDS = 4

  def initialize(message:)
    @message = message
    @conversation = message.conversation
    @assistant = message.inbox.tekomi_assistant
  end

  def perform
    wait_time = attachment_wait_time
    return Tekomi::Conversation::ResponseBuilderJob.perform_later(*job_args) if wait_time.zero?

    Tekomi::Conversation::ResponseBuilderJob.set(wait: wait_time).perform_later(*job_args)
  end

  private

  def job_args
    args = [@conversation, @assistant]
    args << @message.id if tekomi_v2_enabled?
    args
  end

  def tekomi_v2_enabled?
    @conversation.account.feature_enabled?('tekomi_integration_v2')
  end

  def attachment_wait_time
    attachment_count = tekomi_v2_enabled? ? recent_attachment_count : @message.attachments.size
    return 0.seconds if attachment_count.zero?

    base_wait = 1.second
    additional_wait = [attachment_count, MAX_ATTACHMENT_WAIT_SECONDS].min.seconds
    base_wait + additional_wait
  end

  def recent_attachment_count
    maximum_wait = (MAX_ATTACHMENT_WAIT_SECONDS + 1).seconds

    @conversation.messages.incoming
                 .joins(:attachments)
                 .where(attachments: { created_at: maximum_wait.ago.. })
                 .count
  end
end
