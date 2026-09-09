import ApiClient from '../ApiClient';

class CopilotThreads extends ApiClient {
  constructor() {
    super('tekomi/copilot_threads', { accountScoped: true });
  }
}

export default new CopilotThreads();
