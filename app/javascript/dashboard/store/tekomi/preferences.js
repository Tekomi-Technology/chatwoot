import { defineStore } from 'pinia';
import TekomiPreferencesAPI from 'dashboard/api/tekomi/preferences';

export const useTekomiConfigStore = defineStore('tekomiConfig', {
  state: () => ({
    features: {},
    uiFlags: {
      isFetching: false,
    },
  }),

  getters: {
    getFeatures: state => state.features,
    getUIFlags: state => state.uiFlags,
  },

  actions: {
    async fetch() {
      this.uiFlags.isFetching = true;
      try {
        const response = await TekomiPreferencesAPI.get();
        this.features = response.data.features || {};
      } catch (error) {
        // Ignore error
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    async updatePreferences(data) {
      const response = await TekomiPreferencesAPI.updatePreferences(data);
      this.features = response.data.features || {};
    },
  },
});
