module Enterprise::Internal::TriggerDailyScheduledItemsJob
  def perform
    super

    Tekomi::Documents::ScheduleSyncsJob.perform_later('enterprise')
    Tekomi::Documents::ScheduleSyncsJob.perform_later('business') if business_auto_sync_due?
    Tekomi::Documents::ScheduleSyncsJob.perform_later('startups') if startup_auto_sync_due?
  end

  private

  def business_auto_sync_due?
    Time.current.utc.sunday?
  end

  def startup_auto_sync_due?
    Time.current.utc.day == 1
  end
end
