<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAssistantSettings } from './useAssistantSettings';
import SettingsPageLayout from 'dashboard/components-next/tekomi/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantSystemSettingsForm from 'dashboard/components-next/tekomi/pageComponents/assistant/settings/AssistantSystemSettingsForm.vue';

const { t } = useI18n();
const { isCloudFeatureEnabled } = useAccount();
const { assistant, updateAssistant } = useAssistantSettings();

const systemSettingsDescription = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.TEKOMI_V2)
    ? t('TEKOMI.ASSISTANTS.SETTINGS.SYSTEM_SETTINGS.DESCRIPTION_V2')
    : t('TEKOMI.ASSISTANTS.SETTINGS.SYSTEM_SETTINGS.DESCRIPTION')
);
</script>

<template>
  <SettingsPageLayout
    :heading="t('TEKOMI.ASSISTANTS.SETTINGS.SYSTEM_SETTINGS.TITLE')"
    :description="systemSettingsDescription"
  >
    <AssistantSystemSettingsForm
      :assistant="assistant"
      @submit="updateAssistant"
    />
  </SettingsPageLayout>
</template>
