module Enterprise::ActivityMessageHandler
  def automation_status_change_activity_content
    return super unless Current.executed_by.instance_of?(Tekomi::Assistant)

    locale = Current.executed_by.account.locale
    key = tekomi_activity_key
    return unless key

    I18n.t(key, user_name: Current.executed_by.name, reason: tekomi_status_reason, locale: locale)
  end

  private

  def tekomi_status_reason
    tekomi_activity_reason.presence
  end

  def tekomi_activity_key
    return tekomi_resolved_activity_key if resolved?
    return tekomi_open_activity_key if open?
  end

  def tekomi_resolved_activity_key
    return 'conversations.activity.tekomi.resolved_by_tool' if tekomi_activity_reason_type == :tool && tekomi_status_reason.present?
    return 'conversations.activity.tekomi.resolved_with_reason' if tekomi_status_reason.present?

    'conversations.activity.tekomi.resolved'
  end

  def tekomi_open_activity_key
    return 'conversations.activity.tekomi.open_with_reason' if tekomi_status_reason.present?

    'conversations.activity.tekomi.open'
  end
end
