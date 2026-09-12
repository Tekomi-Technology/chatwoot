<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatDuration } from 'shared/helpers/timeHelper';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  details: {
    type: Object,
    default: null,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  hasError: {
    type: Boolean,
    default: false,
  },
});

const { t, locale } = useI18n();
const dialogRef = ref(null);

const present = value => value !== null && value !== undefined && value !== '';

const formatDateTime = value => {
  if (!value) return '';

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;

  return new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'medium',
  }).format(date);
};

const formatValue = value => {
  if (!present(value)) return '';
  if (typeof value === 'object') return JSON.stringify(value, null, 2);
  return String(value);
};

const directionLabel = computed(() =>
  props.details?.direction === 'outbound'
    ? t('CONVERSATION.PHONE_CALL.OUTBOUND')
    : t('CONVERSATION.PHONE_CALL.INBOUND')
);

const statusLabel = computed(() => {
  if (props.details?.status === 'ringing') return directionLabel.value;

  const statusLabels = {
    in_progress: t('CONVERSATION.PHONE_CALL.IN_PROGRESS'),
    completed: t('CONVERSATION.PHONE_CALL.COMPLETED'),
    missed: t('CONVERSATION.PHONE_CALL.MISSED'),
    busy: t('CONVERSATION.PHONE_CALL.BUSY'),
    no_answer: t('CONVERSATION.PHONE_CALL.NO_ANSWER'),
    rejected: t('CONVERSATION.PHONE_CALL.REJECTED'),
    cancelled: t('CONVERSATION.PHONE_CALL.CANCELLED'),
    failed: t('CONVERSATION.PHONE_CALL.FAILED'),
  };
  return statusLabels[props.details?.status] || props.details?.status;
});

const overviewItems = computed(() => {
  if (!props.details) return [];

  return [
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.DIRECTION'),
      value: directionLabel.value,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.STATUS'),
      value: statusLabel.value,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.CUSTOMER_NUMBER'),
      value: props.details.customer_number,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.FROM'),
      value: props.details.from_number,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.TO'),
      value: props.details.to_number,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.DURATION'),
      value: present(props.details.duration_seconds)
        ? formatDuration(props.details.duration_seconds)
        : '',
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.STARTED_AT'),
      value: formatDateTime(props.details.started_at),
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.ANSWERED_AT'),
      value: formatDateTime(props.details.answered_at),
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.ENDED_AT'),
      value: formatDateTime(props.details.ended_at),
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.CAMPAIGN_ID'),
      value: props.details.campaign_id,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.CALL_ID'),
      value: props.details.call_id,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.END_REASON'),
      value: props.details.hangup_cause,
    },
  ].filter(item => present(item.value));
});

const analysisItems = computed(() => {
  if (!props.details) return [];

  return [
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.OUTCOME'),
      value: props.details.outcome,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.ANALYSIS_STATUS'),
      value: props.details.analysis_status,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.CUSTOMER_INTENT'),
      value: props.details.customer_intent,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.DISPOSITION'),
      value: props.details.customer_disposition,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.CALLBACK_STATUS'),
      value: props.details.callback_status,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.RESOLUTION'),
      value: props.details.business_resolution,
    },
    {
      label: t('CONVERSATION.PHONE_CALL.DETAILS.FAILURE_REASON'),
      value: props.details.failure_reason,
    },
  ].filter(item => present(item.value));
});

const hasBusinessData = computed(
  () =>
    Object.keys(props.details?.captured_fields || {}).length > 0 ||
    Object.keys(props.details?.metadata || {}).length > 0 ||
    (props.details?.confirmed_actions || []).length > 0 ||
    (props.details?.actions || []).length > 0
);

const speakerLabel = speaker =>
  speaker === 'user'
    ? t('CONVERSATION.PHONE_CALL.DETAILS.CUSTOMER')
    : t('CONVERSATION.PHONE_CALL.DETAILS.CALLBOT');

const open = () => dialogRef.value?.open();

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    position="top"
    overflow-y-auto
    :title="$t('CONVERSATION.PHONE_CALL.DETAILS.TITLE')"
    :cancel-button-label="$t('CONVERSATION.PHONE_CALL.DETAILS.CLOSE')"
    :show-confirm-button="false"
  >
    <div
      v-if="isLoading"
      class="flex min-h-40 items-center justify-center text-n-slate-11"
    >
      <Icon class="size-6 animate-spin" icon="i-lucide-loader-circle" />
    </div>

    <div
      v-else-if="hasError"
      class="rounded-lg bg-n-ruby-3 p-4 text-sm text-n-ruby-11"
    >
      {{ $t('CONVERSATION.PHONE_CALL.DETAILS.LOAD_ERROR') }}
    </div>

    <div v-else-if="details" class="flex flex-col gap-6 text-n-slate-12">
      <section class="flex flex-col gap-3">
        <h4 class="text-sm font-medium">
          {{ $t('CONVERSATION.PHONE_CALL.DETAILS.OVERVIEW') }}
        </h4>
        <dl
          class="grid grid-cols-1 gap-3 rounded-xl bg-n-alpha-1 p-4 sm:grid-cols-2"
        >
          <div v-for="item in overviewItems" :key="item.label" class="min-w-0">
            <dt class="text-xs text-n-slate-10">{{ item.label }}</dt>
            <dd class="mt-0.5 break-words text-sm">{{ item.value }}</dd>
          </div>
        </dl>
      </section>

      <section
        v-if="details.summary || analysisItems.length"
        class="flex flex-col gap-3"
      >
        <h4 class="text-sm font-medium">
          {{ $t('CONVERSATION.PHONE_CALL.DETAILS.ANALYSIS') }}
        </h4>
        <div
          v-if="details.summary"
          class="rounded-xl bg-n-alpha-1 p-4 text-sm leading-6"
        >
          {{ details.summary }}
        </div>
        <dl
          v-if="analysisItems.length"
          class="grid grid-cols-1 gap-3 sm:grid-cols-2"
        >
          <div v-for="item in analysisItems" :key="item.label" class="min-w-0">
            <dt class="text-xs text-n-slate-10">{{ item.label }}</dt>
            <dd class="mt-0.5 break-words text-sm">{{ item.value }}</dd>
          </div>
        </dl>
      </section>

      <section v-if="hasBusinessData" class="flex flex-col gap-3">
        <h4 class="text-sm font-medium">
          {{ $t('CONVERSATION.PHONE_CALL.DETAILS.BUSINESS_DATA') }}
        </h4>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div
            v-if="Object.keys(details.captured_fields || {}).length"
            class="min-w-0 rounded-xl bg-n-alpha-1 p-4"
          >
            <div class="mb-2 text-xs text-n-slate-10">
              {{ $t('CONVERSATION.PHONE_CALL.DETAILS.CAPTURED_FIELDS') }}
            </div>
            <pre class="m-0 whitespace-pre-wrap break-words text-xs">{{
              formatValue(details.captured_fields)
            }}</pre>
          </div>
          <div
            v-if="Object.keys(details.metadata || {}).length"
            class="min-w-0 rounded-xl bg-n-alpha-1 p-4"
          >
            <div class="mb-2 text-xs text-n-slate-10">
              {{ $t('CONVERSATION.PHONE_CALL.DETAILS.METADATA') }}
            </div>
            <pre class="m-0 whitespace-pre-wrap break-words text-xs">{{
              formatValue(details.metadata)
            }}</pre>
          </div>
          <div
            v-if="details.confirmed_actions?.length"
            class="min-w-0 rounded-xl bg-n-alpha-1 p-4"
          >
            <div class="mb-2 text-xs text-n-slate-10">
              {{ $t('CONVERSATION.PHONE_CALL.DETAILS.CONFIRMED_ACTIONS') }}
            </div>
            <pre class="m-0 whitespace-pre-wrap break-words text-xs">{{
              formatValue(details.confirmed_actions)
            }}</pre>
          </div>
          <div
            v-if="details.actions?.length"
            class="min-w-0 rounded-xl bg-n-alpha-1 p-4"
          >
            <div class="mb-2 text-xs text-n-slate-10">
              {{ $t('CONVERSATION.PHONE_CALL.DETAILS.ACTIONS') }}
            </div>
            <pre class="m-0 whitespace-pre-wrap break-words text-xs">{{
              formatValue(details.actions)
            }}</pre>
          </div>
        </div>
      </section>

      <section class="flex flex-col gap-3">
        <h4 class="text-sm font-medium">
          {{ $t('CONVERSATION.PHONE_CALL.DETAILS.TRANSCRIPT') }}
        </h4>
        <div
          v-if="details.transcript?.length"
          class="flex max-h-[42vh] flex-col gap-3 overflow-y-auto rounded-xl bg-n-alpha-1 p-4"
        >
          <div
            v-for="(turn, index) in details.transcript"
            :key="`${index}-${turn.speaker}`"
            class="flex"
            :class="turn.speaker === 'user' ? 'justify-end' : 'justify-start'"
          >
            <div
              class="max-w-[85%] rounded-xl px-3 py-2"
              :class="
                turn.speaker === 'user'
                  ? 'bg-n-blue-9 text-white'
                  : 'border border-n-weak bg-n-solid-2'
              "
            >
              <div class="mb-1 text-xs opacity-70">
                {{ speakerLabel(turn.speaker) }}
              </div>
              <p class="m-0 whitespace-pre-wrap break-words text-sm leading-5">
                {{ turn.text }}
              </p>
              <div v-if="turn.occurred_at" class="mt-1 text-[11px] opacity-60">
                {{ formatDateTime(turn.occurred_at) }}
              </div>
            </div>
          </div>
        </div>
        <p
          v-else
          class="m-0 rounded-xl bg-n-alpha-1 p-4 text-sm text-n-slate-10"
        >
          {{ $t('CONVERSATION.PHONE_CALL.DETAILS.NO_TRANSCRIPT') }}
        </p>
      </section>
    </div>
  </Dialog>
</template>
