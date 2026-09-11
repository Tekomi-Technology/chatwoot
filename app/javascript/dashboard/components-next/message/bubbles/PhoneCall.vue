<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatDuration } from 'shared/helpers/timeHelper';
import { useMessageContext } from '../provider.js';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import AudioChip from 'next/message/chips/Audio.vue';

const { t } = useI18n();
const { contentAttributes } = useMessageContext();

const call = computed(() => contentAttributes.value?.data || {});
const direction = computed(() => call.value.direction);
const status = computed(() => call.value.status || 'ringing');
const isOutbound = computed(() => direction.value === 'outbound');
const isFailed = computed(() =>
  ['missed', 'busy', 'no_answer', 'rejected', 'cancelled', 'failed'].includes(
    status.value
  )
);

const title = computed(() => {
  if (status.value === 'completed')
    return t('CONVERSATION.PHONE_CALL.COMPLETED');
  if (status.value === 'in_progress')
    return t('CONVERSATION.PHONE_CALL.IN_PROGRESS');
  if (status.value === 'missed') return t('CONVERSATION.PHONE_CALL.MISSED');
  if (status.value === 'busy') return t('CONVERSATION.PHONE_CALL.BUSY');
  if (status.value === 'no_answer')
    return t('CONVERSATION.PHONE_CALL.NO_ANSWER');
  if (status.value === 'rejected') return t('CONVERSATION.PHONE_CALL.REJECTED');
  if (status.value === 'cancelled')
    return t('CONVERSATION.PHONE_CALL.CANCELLED');
  if (status.value === 'failed') return t('CONVERSATION.PHONE_CALL.FAILED');
  return isOutbound.value
    ? t('CONVERSATION.PHONE_CALL.OUTBOUND')
    : t('CONVERSATION.PHONE_CALL.INBOUND');
});

const details = computed(() => {
  const duration =
    call.value.durationSeconds ?? call.value.duration_seconds ?? null;
  return [
    call.value.customerNumber || call.value.customer_number,
    call.value.agentName || call.value.agent_name,
    duration ? formatDuration(duration) : null,
  ]
    .filter(Boolean)
    .join(' · ');
});

const iconName = computed(() => {
  if (isFailed.value) return 'i-ph-phone-x-bold';
  return isOutbound.value
    ? 'i-ph-phone-outgoing-bold'
    : 'i-ph-phone-incoming-bold';
});

const iconClass = computed(() => {
  if (isFailed.value) return 'bg-n-ruby-3 text-n-ruby-10';
  if (['ringing', 'in_progress'].includes(status.value))
    return 'bg-n-teal-3 text-n-teal-11';
  return 'bg-n-alpha-2 text-n-slate-12';
});

const recordingAttachment = computed(() => {
  const recordingUrl = call.value.recordingUrl || call.value.recording_url;
  if (!recordingUrl) return null;
  return {
    dataUrl: recordingUrl,
    fileType: 'audio',
    extension: 'wav',
  };
});

const callbotSummary = computed(
  () => call.value.callbotSummary || call.value.callbot_summary
);
</script>

<template>
  <BaseBubble class="!max-w-md !p-3 min-w-[240px]" hide-meta>
    <div class="flex w-full flex-col gap-3">
      <div class="flex items-start gap-2.5">
        <div
          class="flex size-11 shrink-0 items-center justify-center rounded-xl"
          :class="iconClass"
        >
          <Icon class="size-4" :icon="iconName" />
        </div>
        <div class="flex min-w-0 flex-1 flex-col self-center">
          <span class="truncate text-sm font-medium leading-tight">
            {{ title }}
          </span>
          <span v-if="details" class="truncate text-sm opacity-75">
            {{ details }}
          </span>
          <span
            v-if="callbotSummary"
            class="mt-1 line-clamp-2 text-sm opacity-75"
          >
            {{ callbotSummary }}
          </span>
        </div>
      </div>

      <AudioChip
        v-if="recordingAttachment"
        :attachment="recordingAttachment"
        :show-transcribed-text="false"
      />
    </div>
  </BaseBubble>
</template>
