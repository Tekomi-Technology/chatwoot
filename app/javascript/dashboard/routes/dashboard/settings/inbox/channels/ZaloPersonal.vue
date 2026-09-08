<script setup>
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useZaloQrLogin } from 'dashboard/composables/useZaloQrLogin';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const router = useRouter();
const route = useRoute();

// Setting up an inbox continues into the agent step; the conversation banner instead stays where
// it is, which is why the shared composable leaves the success handling to its caller.
const {
  qrImage,
  isStarting,
  isExpired,
  errorCode,
  isWaitingForScan,
  errorMessage,
  connect,
} = useZaloQrLogin(data => {
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: { page: 'new', inbox_id: data.inbox_id },
  });
});

const onConnect = async () => {
  try {
    // channel_id is present only when re-authenticating an inbox whose session expired.
    await connect(route.query.channel_id);
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.ERROR.GENERIC')
    );
  }
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.DESC')"
    />

    <div class="flex flex-col items-start gap-4 mt-4">
      <p
        v-if="!qrImage"
        class="text-sm text-n-slate-11 max-w-lg"
        :class="{ 'text-n-ruby-11': errorMessage }"
      >
        {{
          errorMessage ||
          (isExpired
            ? $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.EXPIRED')
            : $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.INTRO'))
        }}
      </p>

      <template v-if="isWaitingForScan">
        <img
          :src="qrImage"
          :alt="$t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.ALT')"
          class="w-56 h-56 rounded-lg border border-n-weak bg-white p-2"
        />
        <p class="text-sm text-n-slate-11 max-w-lg">
          {{ $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.INSTRUCTIONS') }}
        </p>
      </template>

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
        @click="onConnect"
      />
    </div>
  </div>
</template>
