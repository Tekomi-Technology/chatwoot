<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useTekomiConfigStore } from 'dashboard/store/tekomi/preferences';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  featureKey: {
    type: String,
    required: true,
  },
  isAllowed: {
    type: Boolean,
    required: true,
  },
});

const emit = defineEmits(['change']);

const { t } = useI18n();
const tekomiConfigStore = useTekomiConfigStore();
const { features } = storeToRefs(tekomiConfigStore);

const isEnabled = ref(false);

const featureConfig = computed(() => features.value[props.featureKey]);

const title = computed(() => {
  if (props.featureKey.toUpperCase() === 'AUDIO_TRANSCRIPTION') {
    return t('TEKOMI_SETTINGS.FEATURES.AUDIO_TRANSCRIPTION.TITLE');
  }
  if (props.featureKey.toUpperCase() === 'HELP_CENTER_SEARCH') {
    return t('TEKOMI_SETTINGS.FEATURES.HELP_CENTER_SEARCH.TITLE');
  }
  if (props.featureKey.toUpperCase() === 'LABEL_SUGGESTION') {
    return t('TEKOMI_SETTINGS.FEATURES.LABEL_SUGGESTION.TITLE');
  }
  return '';
});

const description = computed(() => {
  if (props.featureKey.toUpperCase() === 'AUDIO_TRANSCRIPTION') {
    return t('TEKOMI_SETTINGS.FEATURES.AUDIO_TRANSCRIPTION.DESCRIPTION');
  }
  if (props.featureKey.toUpperCase() === 'HELP_CENTER_SEARCH') {
    return t('TEKOMI_SETTINGS.FEATURES.HELP_CENTER_SEARCH.DESCRIPTION');
  }
  if (props.featureKey.toUpperCase() === 'LABEL_SUGGESTION') {
    return t('TEKOMI_SETTINGS.FEATURES.LABEL_SUGGESTION.DESCRIPTION');
  }
  return '';
});

watch(
  featureConfig,
  newConfig => {
    if (newConfig !== undefined) {
      isEnabled.value = !!newConfig.enabled;
    }
  },
  { immediate: true }
);

const toggleFeature = () => {
  emit('change', { feature: props.featureKey, enabled: isEnabled.value });
};
</script>

<template>
  <div
    class="p-4 rounded-xl border border-n-weak bg-n-solid-1 flex items-center justify-between gap-4"
    :class="{ 'opacity-60 pointer-events-none': !isAllowed }"
  >
    <div class="flex-1 min-w-0">
      <h4 class="text-sm font-medium text-n-slate-12">{{ title }}</h4>
      <p class="text-sm text-n-slate-11 mt-0.5">{{ description }}</p>
    </div>
    <div v-if="isAllowed" class="flex-shrink-0">
      <Switch v-model="isEnabled" @change="toggleFeature" />
    </div>
  </div>
</template>
