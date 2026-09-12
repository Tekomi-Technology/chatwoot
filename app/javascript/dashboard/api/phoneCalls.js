import ApiClient from './ApiClient';

class PhoneCalls extends ApiClient {
  constructor() {
    super('phone_calls', { accountScoped: true });
  }
}

export default new PhoneCalls();
