import { computed, onMounted } from 'vue';
import { storeToRefs } from 'pinia';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useTekomiConfigStore } from 'dashboard/store/tekomi/preferences';
import TasksAPI from 'dashboard/api/tekomi/tasks';

/**
 * Cleans and normalizes a list of labels.
 * @param {string} labels - A comma-separated string of labels.
 * @returns {string[]} An array of cleaned and unique labels.
 */
const cleanLabels = labels => {
  return labels
    .toLowerCase()
    .split(',')
    .filter(label => label.trim())
    .map(label => label.trim())
    .filter((label, index, self) => self.indexOf(label) === index);
};

export function useLabelSuggestions() {
  const { isCloudFeatureEnabled } = useAccount();
  const tekomiConfigStore = useTekomiConfigStore();
  const { features } = storeToRefs(tekomiConfigStore);
  const currentChat = useMapGetter('getSelectedChat');
  const conversationId = computed(() => currentChat.value?.id);

  const tekomiTasksEnabled = computed(() => {
    return isCloudFeatureEnabled(FEATURE_FLAGS.TEKOMI_TASKS);
  });

  const isLabelSuggestionFeatureEnabled = computed(
    () => !!features.value.label_suggestion?.enabled
  );

  /**
   * Gets label suggestions for the current conversation.
   * @returns {Promise<string[]>} An array of suggested labels.
   */
  const getLabelSuggestions = async () => {
    if (!conversationId.value) return [];

    try {
      const result = await TasksAPI.labelSuggestion(conversationId.value);
      const {
        data: { message: labels },
      } = result;
      return cleanLabels(labels);
    } catch {
      return [];
    }
  };

  onMounted(() => {
    if (!Object.keys(features.value).length) {
      tekomiConfigStore.fetch();
    }
  });

  return {
    tekomiTasksEnabled,
    isLabelSuggestionFeatureEnabled,
    getLabelSuggestions,
  };
}
