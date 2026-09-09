import TekomiResponseAPI from 'dashboard/api/tekomi/response';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'TekomiResponse',
  API: TekomiResponseAPI,
  actions: mutations => ({
    setFetchingList({ commit }, isFetching) {
      commit(mutations.SET_UI_FLAG, { fetchingList: isFetching });
    },
    setRecords({ commit }, { records, meta }) {
      commit(mutations.SET, records);
      commit(mutations.SET_META, meta);
    },
    removeBulkResponses: ({ commit, state }, ids) => {
      const updatedRecords = state.records.filter(
        record => !ids.includes(record.id)
      );
      commit(mutations.SET, updatedRecords);
    },
  }),
});
