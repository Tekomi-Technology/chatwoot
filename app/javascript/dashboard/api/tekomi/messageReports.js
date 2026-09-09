import ApiClient from '../ApiClient';

class MessageReports extends ApiClient {
  constructor() {
    super('tekomi/message_reports', { accountScoped: true });
  }
}

export default new MessageReports();
