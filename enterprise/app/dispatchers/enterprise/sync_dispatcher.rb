module Enterprise::SyncDispatcher
  def listeners
    super + [
      Tekomi::ConversationOutcomeEventListener.instance
    ]
  end
end
