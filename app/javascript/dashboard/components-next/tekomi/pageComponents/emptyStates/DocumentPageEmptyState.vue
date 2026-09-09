<script setup>
import { useAccount } from 'dashboard/composables/useAccount';
import { useBranding } from 'shared/composables/useBranding';
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DocumentCard from 'dashboard/components-next/tekomi/assistant/DocumentCard.vue';
import FeatureSpotlight from 'dashboard/components-next/feature-spotlight/FeatureSpotlight.vue';
import { documentsList } from 'dashboard/components-next/tekomi/pageComponents/emptyStates/tekomiEmptyStateContent.js';

const emit = defineEmits(['click']);
const { isOnChatwootCloud } = useAccount();

const { replaceInstallationName } = useBranding();

const onClick = () => {
  emit('click');
};
</script>

<template>
  <FeatureSpotlight
    :title="$t('TEKOMI.DOCUMENTS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
    :note="$t('TEKOMI.DOCUMENTS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
    fallback-thumbnail="/assets/images/dashboard/tekomi/document-light.svg"
    fallback-thumbnail-dark="/assets/images/dashboard/tekomi/document-dark.svg"
    learn-more-url="https://chwt.app/tekomi-document"
    :hide-actions="!isOnChatwootCloud"
    class="mb-8"
  />
  <EmptyStateLayout
    :title="$t('TEKOMI.DOCUMENTS.EMPTY_STATE.TITLE')"
    :subtitle="$t('TEKOMI.DOCUMENTS.EMPTY_STATE.SUBTITLE')"
    :action-perms="['administrator']"
  >
    <template #empty-state-item>
      <div class="grid grid-cols-1 gap-4 p-px overflow-hidden">
        <DocumentCard
          v-for="(document, index) in documentsList.slice(0, 5)"
          :id="document.id"
          :key="`document-${index}`"
          :name="replaceInstallationName(document.name)"
          :assistant="document.assistant"
          :external-link="document.external_link"
          :created-at="document.created_at"
        />
      </div>
    </template>
    <template #actions>
      <Button
        :label="$t('TEKOMI.DOCUMENTS.ADD_NEW')"
        icon="i-lucide-plus"
        @click="onClick"
      />
    </template>
  </EmptyStateLayout>
</template>
