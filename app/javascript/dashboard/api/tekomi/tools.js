/* global axios */
import ApiClient from '../ApiClient';

class TekomiTools extends ApiClient {
  constructor() {
    super('tekomi/assistants/tools', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, {
      params,
    });
  }
}

export default new TekomiTools();
