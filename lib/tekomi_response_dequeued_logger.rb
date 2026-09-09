# Records the Sidekiq fetch boundary for Tekomi response jobs without logging every job.
class TekomiResponseDequeuedLogger
  JOB_CLASS = 'Tekomi::Conversation::ResponseBuilderJob'.freeze

  def call(_worker, job, queue)
    log_dequeued(job, queue) if tekomi_v2_response_job?(job)
    yield
  end

  private

  def log_dequeued(job, queue)
    active_job_id = job.dig('args', 0, 'job_id')
    responding_to_message_id = job.dig('args', 0, 'arguments', 2)
    Sidekiq.logger.info(
      "[TEKOMI][ResponseLifecycle] event=job_dequeued active_job_id=#{active_job_id} provider_job_id=#{job['jid']} " \
      "responding_to_message_id=#{responding_to_message_id} queue=#{queue}"
    )
  end

  def tekomi_v2_response_job?(job)
    return false unless job['wrapped'] == JOB_CLASS

    !job.dig('args', 0, 'arguments', 2).nil?
  end
end
