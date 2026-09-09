json.payload do
  json.array! @copilot_messages do |message|
    json.partial! 'api/v1/models/tekomi/copilot_message', formats: [:json], resource: message
  end
end
