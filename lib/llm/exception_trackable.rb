module Llm::ExceptionTrackable
  private

  def capture_llm_exception(error)
    ChatwootExceptionTracker.new(error, account: exception_tracking_account).capture_exception
  end
end
