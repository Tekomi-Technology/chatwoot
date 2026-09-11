/* global axios */
import ApiClient from './ApiClient';

class CallbotWebhooks extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  getAll(inboxId) {
    return axios.get(`${this.url}/${inboxId}/callbot_webhooks`);
  }

  create(inboxId, webhook) {
    return axios.post(`${this.url}/${inboxId}/callbot_webhooks`, {
      callbot_webhook: webhook,
    });
  }

  update(inboxId, id, webhook) {
    return axios.patch(`${this.url}/${inboxId}/callbot_webhooks/${id}`, {
      callbot_webhook: webhook,
    });
  }

  delete(inboxId, id) {
    return axios.delete(`${this.url}/${inboxId}/callbot_webhooks/${id}`);
  }
}

export default new CallbotWebhooks();
