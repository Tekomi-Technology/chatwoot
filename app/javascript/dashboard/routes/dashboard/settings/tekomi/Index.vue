<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useTekomi } from 'dashboard/composables/useTekomi';
import { useConfig } from 'dashboard/composables/useConfig';
import { useTekomiConfigStore } from 'dashboard/store/tekomi/preferences';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import ModelSelector from './components/ModelSelector.vue';
import FeatureToggle from './components/FeatureToggle.vue';
import TekomiPaywall from 'next/tekomi/pageComponents/Paywall.vue';

const { t } = useI18n();
const { tekomiEnabled } = useTekomi();
const { isEnterprise } = useConfig();
const { isOnChatwootCloud } = useAccount();

const tekomiConfigStore = useTekomiConfigStore();
const { uiFlags } = storeToRefs(tekomiConfigStore);

const isLoading = computed(() => uiFlags.value.isFetching);

const modelFeatures = computed(() => [
  {
    key: 'editor',
    title: t('TEKOMI_SETTINGS.MODEL_CONFIG.EDITOR.TITLE'),
    description: t('TEKOMI_SETTINGS.MODEL_CONFIG.EDITOR.DESCRIPTION'),
  },
  {
    key: 'assistant',
    title: t('TEKOMI_SETTINGS.MODEL_CONFIG.ASSISTANT.TITLE'),
    description: t('TEKOMI_SETTINGS.MODEL_CONFIG.ASSISTANT.DESCRIPTION'),
    enterprise: true,
  },
  {
    key: 'copilot',
    title: t('TEKOMI_SETTINGS.MODEL_CONFIG.COPILOT.TITLE'),
    description: t('TEKOMI_SETTINGS.MODEL_CONFIG.COPILOT.DESCRIPTION'),
    enterprise: true,
  },
]);

const featureToggles = computed(() => [
  {
    key: 'label_suggestion',
  },
  {
    key: 'help_center_search',
    enterprise: true,
  },
  {
    key: 'audio_transcription',
    enterprise: true,
  },
]);

const shouldShowFeature = feature => {
  // Cloud will always see these features as long as tekomi is enabled
  if (isOnChatwootCloud.value && tekomiEnabled) {
    return true;
  }

  if (feature.enterprise) {
    // if the app is in enterprise mode, then we can show the feature
    // this is not the installation plan, but when the enterprise folder is missing
    return isEnterprise;
  }

  return true;
};

const isFeatureAccessible = feature => {
  // Cloud will always see these features as long as tekomi is enabled
  if (isOnChatwootCloud.value && tekomiEnabled) {
    return true;
  }

  if (feature.enterprise) {
    return isEnterprise;
  }

  return true;
};

async function handleFeatureToggle({ feature, enabled }) {
  try {
    await tekomiConfigStore.updatePreferences({
      tekomi_features: { [feature]: enabled },
    });
    useAlert(t('TEKOMI_SETTINGS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.API.ERROR'));
    tekomiConfigStore.fetch();
  }
}

async function handleModelChange({ feature, model }) {
  try {
    await tekomiConfigStore.updatePreferences({
      tekomi_models: { [feature]: model },
    });
    useAlert(t('TEKOMI_SETTINGS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.API.ERROR'));
    tekomiConfigStore.fetch();
  }
}

onMounted(() => {
  tekomiConfigStore.fetch();
});
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :no-records-message="t('TEKOMI_SETTINGS.NOT_ENABLED')"
    :loading-message="t('TEKOMI_SETTINGS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('TEKOMI_SETTINGS.TITLE')"
        :description="t('TEKOMI_SETTINGS.DESCRIPTION')"
        :link-text="t('TEKOMI_SETTINGS.LINK_TEXT')"
        icon-name="tekomi"
        feature-name="tekomi_billing"
      />
    </template>
    <template #body>
      <div v-if="tekomiEnabled" class="flex flex-col gap-1">
        <!-- Model Configuration Section -->
        <SectionLayout
          :title="t('TEKOMI_SETTINGS.MODEL_CONFIG.TITLE')"
          :description="t('TEKOMI_SETTINGS.MODEL_CONFIG.DESCRIPTION')"
        >
          <div class="grid gap-4">
            <ModelSelector
              v-for="feature in modelFeatures"
              v-show="shouldShowFeature(feature)"
              :key="feature.key"
              :is-allowed="isFeatureAccessible(feature)"
              :feature-key="feature.key"
              :title="feature.title"
              :description="feature.description"
              @change="handleModelChange"
            />
          </div>
        </SectionLayout>

        <!-- Features Section -->
        <SectionLayout
          :title="t('TEKOMI_SETTINGS.FEATURES.TITLE')"
          :description="t('TEKOMI_SETTINGS.FEATURES.DESCRIPTION')"
          with-border
        >
          <div class="grid gap-4">
            <FeatureToggle
              v-for="feature in featureToggles"
              v-show="shouldShowFeature(feature)"
              :key="feature.key"
              :is-allowed="isFeatureAccessible(feature)"
              :feature-key="feature.key"
              @change="handleFeatureToggle"
              @model-change="handleModelChange"
            />
          </div>
        </SectionLayout>
      </div>
      <div v-else>
        <TekomiPaywall />
      </div>
    </template>
  </SettingsLayout>
</template>
