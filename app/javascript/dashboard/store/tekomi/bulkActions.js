import TekomiBulkActionsAPI from 'dashboard/api/tekomi/bulkActions';
import { createStore } from '../storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export default createStore({
  name: 'TekomiBulkAction',
  API: TekomiBulkActionsAPI,
  actions: mutations => ({
    processBulkAction: async function processBulkAction(
      { commit },
      { type, actionType, ids }
    ) {
      commit(mutations.SET_UI_FLAG, { isUpdating: true });
      try {
        const response = await TekomiBulkActionsAPI.create({
          type: type,
          ids,
          fields: { status: actionType },
        });
        commit(mutations.SET_UI_FLAG, { isUpdating: false });
        return response.data;
      } catch (error) {
        commit(mutations.SET_UI_FLAG, { isUpdating: false });
        return throwErrorMessage(error);
      }
    },

    handleBulkDelete: async function handleBulkDelete(
      { dispatch },
      { type = 'AssistantResponse', ids }
    ) {
      const response = await dispatch('processBulkAction', {
        type,
        actionType: 'delete',
        ids,
      });

      if (type === 'AssistantResponse') {
        // Update the response store after successful API call
        await dispatch('tekomiResponses/removeBulkResponses', ids, {
          root: true,
        });
      } else if (type === 'AssistantDocument') {
        await dispatch('tekomiDocuments/removeBulkRecords', ids, {
          root: true,
        });
      }
      return response;
    },

    handleBulkSync: async function handleBulkSync({ dispatch }, { ids }) {
      const response = await dispatch('processBulkAction', {
        type: 'AssistantDocument',
        actionType: 'sync',
        ids,
      });

      await dispatch('tekomiDocuments/markSyncing', response.ids || [], {
        root: true,
      });
      return response;
    },
  }),
});
