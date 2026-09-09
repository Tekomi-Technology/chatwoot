module Enterprise::AsyncDispatcher
  def listeners
    super + [
      TekomiListener.instance,
      Tekomi::ReportingEventListener.instance
    ]
  end
end
