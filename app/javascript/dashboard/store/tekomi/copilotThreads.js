import CopilotThreadsAPI from 'dashboard/api/tekomi/copilotThreads';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'CopilotThreads',
  API: CopilotThreadsAPI,
});
