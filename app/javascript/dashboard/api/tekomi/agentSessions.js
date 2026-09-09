import ApiClient from '../ApiClient';

class TekomiAgentSessions extends ApiClient {
  constructor() {
    super('tekomi/agent_sessions', { accountScoped: true });
  }
}

export default new TekomiAgentSessions();
