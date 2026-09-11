module Concerns::Agentable
  extend ActiveSupport::Concern

  DEFAULT_TEMPERATURE = 0.5

  DEFAULT_MAX_TOKENS = 4000

  def agent
    route = agent_llm_route
    Agents::Agent.new(
      name: agent_name,
      instructions: ->(context) { agent_instructions(context) },
      tools: agent_tools,
      model: route[:model],
      provider: route[:provider],
      assume_model_exists: true,
      temperature: temperature.presence&.to_f || DEFAULT_TEMPERATURE,
      response_schema: agent_response_schema,
      params: { max_tokens: DEFAULT_MAX_TOKENS }
    )
  end

  def agent_instructions(context = nil, prompt_template: template_name)
    enhanced_context = prompt_context

    if context
      state = context.context[:state] || {}
      config = state[:assistant_config] || {}
      enhanced_context = enhanced_context.merge(
        current_time: format_current_time(state[:timezone]),
        conversation: state[:conversation] || {},
        contact: config['feature_contact_attributes'].present? ? state[:contact] : nil,
        campaign: state[:campaign] || {},
        message_length_limit: state[:message_length_limit]
      )
    end

    Tekomi::PromptRenderer.render(prompt_template, enhanced_context.with_indifferent_access)
  end

  def agent_llm_route
    Llm::FeatureRouter.resolve(feature: 'assistant')
  end

  private

  def agent_name
    raise NotImplementedError, "#{self.class} must implement agent_name"
  end

  def template_name
    self.class.name.demodulize.underscore
  end

  def agent_tools
    []  # Default implementation, override if needed
  end

  def agent_response_schema
    Tekomi::ResponseSchema
  end

  def format_current_time(timezone)
    tz = ActiveSupport::TimeZone[timezone] if timezone.present?
    time = tz ? Time.current.in_time_zone(tz) : Time.current
    time.strftime('%A, %B %d, %Y %I:%M %p %Z')
  end

  def prompt_context
    raise NotImplementedError, "#{self.class} must implement prompt_context"
  end
end
