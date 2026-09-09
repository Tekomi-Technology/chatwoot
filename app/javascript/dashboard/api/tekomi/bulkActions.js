import ApiClient from '../ApiClient';

class TekomiBulkActionsAPI extends ApiClient {
  constructor() {
    super('tekomi/bulk_actions', { accountScoped: true });
  }
}

export default new TekomiBulkActionsAPI();
