<script setup>
import { useAccount } from 'dashboard/composables/useAccount';
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import FeatureSpotlight from 'dashboard/components-next/feature-spotlight/FeatureSpotlight.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['click']);
const { isOnChatwootCloud } = useAccount();

const onClick = () => {
  emit('click');
};
</script>

<template>
  <FeatureSpotlight
    :title="$t('TEKOMI.CUSTOM_TOOLS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
    :note="$t('TEKOMI.CUSTOM_TOOLS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
    fallback-thumbnail="/assets/images/dashboard/tekomi/assistant-light.svg"
    fallback-thumbnail-dark="/assets/images/dashboard/tekomi/assistant-dark.svg"
    learn-more-url="https://chwt.app/hc/tekomi-tools"
    class="mb-8"
    :hide-actions="!isOnChatwootCloud"
  />
  <EmptyStateLayout
    :title="$t('TEKOMI.CUSTOM_TOOLS.EMPTY_STATE.TITLE')"
    :subtitle="$t('TEKOMI.CUSTOM_TOOLS.EMPTY_STATE.SUBTITLE')"
    :action-perms="['administrator']"
  >
    <template #empty-state-item>
      <div class="min-h-[600px]" />
    </template>
    <template #actions>
      <Button
        :label="$t('TEKOMI.CUSTOM_TOOLS.ADD_NEW')"
        icon="i-lucide-plus"
        @click="onClick"
      />
    </template>
  </EmptyStateLayout>
</template>
