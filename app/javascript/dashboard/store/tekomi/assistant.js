import TekomiAssistantAPI from 'dashboard/api/tekomi/assistant';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'TekomiAssistant',
  API: TekomiAssistantAPI,
});
