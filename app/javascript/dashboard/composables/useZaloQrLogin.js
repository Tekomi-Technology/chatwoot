import { ref, computed, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import ZaloPersonalChannel from 'dashboard/api/channel/zaloPersonalChannel';

// A Zalo QR code stops being scannable after a couple of minutes, so the caller offers a fresh
// one rather than leaving a dead image on screen.
const POLL_INTERVAL = 2000;

/**
 * Drives a Zalo personal QR login: starts one, polls until the scan completes, and exposes the
 * state a screen needs to render it. Shared by the inbox setup page and the conversation banner,
 * which differ only in what they do once the scan succeeds.
 *
 * @param {Function} onSuccess - called with the poll payload (carries inbox_id) once scanned
 */
export function useZaloQrLogin(onSuccess) {
  const { t } = useI18n();

  const qrImage = ref('');
  const isStarting = ref(false);
  const isExpired = ref(false);
  const errorCode = ref('');

  let pollTimer = null;

  const stopPolling = () => {
    if (pollTimer) clearInterval(pollTimer);
    pollTimer = null;
  };

  onBeforeUnmount(stopPolling);

  const isWaitingForScan = computed(
    () => Boolean(qrImage.value) && !isExpired.value && !errorCode.value
  );

  const errorMessage = computed(() => {
    if (!errorCode.value) return '';
    if (errorCode.value === 'account_mismatch')
      return t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.ERROR.ACCOUNT_MISMATCH');
    if (errorCode.value === 'declined')
      return t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.ERROR.DECLINED');
    return t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.ERROR.GENERIC');
  });

  const expire = () => {
    stopPolling();
    qrImage.value = '';
    isExpired.value = true;
  };

  const fail = code => {
    stopPolling();
    qrImage.value = '';
    errorCode.value = code;
  };

  const poll = async qrSessionId => {
    try {
      const { data } = await ZaloPersonalChannel.getAuthorization(qrSessionId);
      if (data.status === 'success') {
        stopPolling();
        onSuccess(data);
      } else if (data.status === 'expired') {
        expire();
      } else if (data.status === 'error') {
        fail(data.error);
      }
    } catch (error) {
      fail('generic');
    }
  };

  // channelId is present only when re-authenticating an inbox whose session expired.
  const connect = async channelId => {
    isStarting.value = true;
    isExpired.value = false;
    errorCode.value = '';
    try {
      const { data } = await ZaloPersonalChannel.startAuthorization(channelId);
      qrImage.value = data.qr_image;
      pollTimer = setInterval(() => poll(data.qr_session_id), POLL_INTERVAL);
    } finally {
      isStarting.value = false;
    }
  };

  const reset = () => {
    stopPolling();
    qrImage.value = '';
    isExpired.value = false;
    errorCode.value = '';
  };

  return {
    qrImage,
    isStarting,
    isExpired,
    errorCode,
    isWaitingForScan,
    errorMessage,
    connect,
    reset,
  };
}
