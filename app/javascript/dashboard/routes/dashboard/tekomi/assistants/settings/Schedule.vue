<script setup>
import { useI18n } from 'vue-i18n';
import { useAssistantSettings } from './useAssistantSettings';
import SettingsPageLayout from 'dashboard/components-next/tekomi/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantScheduleForm from 'dashboard/components-next/tekomi/pageComponents/assistant/settings/AssistantScheduleForm.vue';

const { t } = useI18n();
const { assistant, updateAssistant } = useAssistantSettings();
</script>

<template>
  <SettingsPageLayout
    :heading="t('TEKOMI.ASSISTANTS.SETTINGS.SCHEDULE.TITLE')"
    :description="t('TEKOMI.ASSISTANTS.SETTINGS.SCHEDULE.DESCRIPTION')"
  >
    <AssistantScheduleForm :assistant="assistant" @submit="updateAssistant" />
  </SettingsPageLayout>
</template>
