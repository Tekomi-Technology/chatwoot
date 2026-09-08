<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useInbox } from 'dashboard/composables/useInbox';
import { useZaloQrLogin } from 'dashboard/composables/useZaloQrLogin';

import Banner from 'dashboard/components/ui/Banner.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();
const { inbox, isAZaloPersonalChannel } = useInbox();

const dialogRef = ref(null);

const isSessionExpired = computed(
  () =>
    isAZaloPersonalChannel.value && inbox.value?.zaloSessionStatus === 'expired'
);

const bannerMessage = computed(() =>
  isAdmin.value
    ? t('CONVERSATION.ZALO_SESSION_EXPIRED.MESSAGE')
    : t('CONVERSATION.ZALO_SESSION_EXPIRED.MESSAGE_AGENT')
);

const {
  qrImage,
  isStarting,
  isExpired,
  errorCode,
  isWaitingForScan,
  errorMessage,
  connect,
  reset,
} = useZaloQrLogin(async () => {
  // The channel is already out of `expired` by the time the scan reports success, so one refetch
  // is enough to drop this banner and leave the agent on the conversation they were reading.
  await store.dispatch('inboxes/get');
  dialogRef.value?.close();
  useAlert(t('CONVERSATION.ZALO_SESSION_EXPIRED.RECONNECTED'));
});

const startScan = async () => {
  reset();
  dialogRef.value?.open();
  try {
    await connect(inbox.value?.channelId);
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.ERROR.GENERIC')
    );
  }
};
</script>

<template>
  <Banner
    v-if="isSessionExpired"
    class="mx-2 mt-2 min-h-12 !h-auto overflow-hidden rounded-lg !pr-16"
    color-scheme="alert"
    :banner-message="bannerMessage"
    :has-action-button="isAdmin"
    action-button-variant="ghost"
    action-button-icon="i-lucide-qr-code"
    :action-button-label="$t('CONVERSATION.ZALO_SESSION_EXPIRED.SCAN')"
    @primary-action="startScan"
  />

  <Dialog
    ref="dialogRef"
    type="edit"
    width="md"
    :title="$t('CONVERSATION.ZALO_SESSION_EXPIRED.DIALOG_TITLE')"
    :description="$t('CONVERSATION.ZALO_SESSION_EXPIRED.DIALOG_DESCRIPTION')"
    :show-confirm-button="false"
    :cancel-button-label="$t('CONVERSATION.ZALO_SESSION_EXPIRED.CLOSE')"
  >
    <div class="flex flex-col items-center gap-4 py-2">
      <img
        v-if="isWaitingForScan"
        :src="qrImage"
        :alt="$t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.ALT')"
        class="w-56 h-56 rounded-lg border border-n-weak bg-white p-2"
      />
      <p
        v-else
        class="text-sm text-center text-n-slate-11"
        :class="{ 'text-n-ruby-11': errorMessage }"
      >
        {{
          errorMessage ||
          (isExpired
            ? $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.EXPIRED')
            : $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.INTRO'))
        }}
      </p>

      <p v-if="isWaitingForScan" class="text-sm text-center text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.INSTRUCTIONS') }}
      </p>

      <NextButton
        v-if="!isWaitingForScan"
        :is-loading="isStarting"
        solid
        blue
        :label="
          isExpired || errorCode
            ? $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.REGENERATE')
            : $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.SUBMIT_BUTTON')
        "
        @click="startScan"
      />
    </div>
  </Dialog>
</template>
