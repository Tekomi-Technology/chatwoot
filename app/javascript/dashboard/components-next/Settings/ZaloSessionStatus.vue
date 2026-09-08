<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';

// A personal Zalo session expires on Zalo's terms, not on a schedule, so the inbox shows its
// live state: an expired session silently stops both directions until someone rescans. The most
// common cause is the account being signed in to Zalo Web elsewhere — Zalo keeps one web session
// per account and drops this one — so the expired state says that rather than leaving the
// operator to guess the inbox is broken.
const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const router = useRouter();

const DOT_COLORS = {
  connected: 'bg-n-teal-10',
  reconnecting: 'bg-n-amber-10',
  expired: 'bg-n-ruby-10',
};

const status = computed(
  () => props.inbox.zalo_session_status || 'reconnecting'
);
const dotColor = computed(
  () => DOT_COLORS[status.value] || DOT_COLORS.reconnecting
);
const needsRescan = computed(() => status.value === 'expired');

const statusLabel = computed(() => {
  if (status.value === 'connected')
    return t('INBOX_MGMT.ZALO_PERSONAL_SESSION.STATUS.CONNECTED');
  if (status.value === 'expired')
    return t('INBOX_MGMT.ZALO_PERSONAL_SESSION.STATUS.EXPIRED');
  return t('INBOX_MGMT.ZALO_PERSONAL_SESSION.STATUS.RECONNECTING');
});

const detail = computed(() => {
  if (status.value === 'connected') return props.inbox.zalo_display_name || '';
  if (!props.inbox.zalo_status_updated_at) return '';
  return t('INBOX_MGMT.ZALO_PERSONAL_SESSION.SINCE', {
    time: dynamicTime(props.inbox.zalo_status_updated_at),
  });
});

const rescan = () => {
  router.push({
    name: 'settings_inboxes_page_channel',
    params: { page: 'new', sub_page: 'zalo_personal' },
    query: { channel_id: props.inbox.channel_id },
  });
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div class="flex items-center gap-2">
        <span class="w-2 h-2 rounded-full" :class="dotColor" />
        <span class="text-sm font-medium text-n-slate-12">
          {{ statusLabel }}
        </span>
        <span v-if="detail" class="text-sm text-n-slate-11">{{ detail }}</span>
      </div>
      <NextButton
        v-if="needsRescan"
        sm
        solid
        blue
        :label="$t('INBOX_MGMT.ZALO_PERSONAL_SESSION.RESCAN')"
        @click="rescan"
      />
    </div>
    <p v-if="needsRescan" class="text-sm text-n-slate-11 max-w-lg">
      {{ $t('INBOX_MGMT.ZALO_PERSONAL_SESSION.EXPIRED_HINT') }}
    </p>
  </div>
</template>
