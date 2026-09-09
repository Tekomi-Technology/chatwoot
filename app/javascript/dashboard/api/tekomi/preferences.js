/* global axios */
import ApiClient from '../ApiClient';

class TekomiPreferences extends ApiClient {
  constructor() {
    super('tekomi/preferences', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  updatePreferences(data) {
    return axios.put(this.url, data);
  }
}

export default new TekomiPreferences();
