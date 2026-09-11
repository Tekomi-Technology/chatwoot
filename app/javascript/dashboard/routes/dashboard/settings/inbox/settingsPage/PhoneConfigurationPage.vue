<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import phoneExtensionsAPI from 'dashboard/api/phoneExtensions';
import callbotWebhooksAPI from 'dashboard/api/callbotWebhooks';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();

const members = ref([]);
const extensions = ref([]);
const callbotWebhooks = ref([]);
const isSavingChannel = ref(false);
const savingUserId = ref(null);
const deletingUserId = ref(null);
const wssUrl = ref('');
const sipDomain = ref('');
const stunUrls = ref('');
const turnUrls = ref('');
const turnSharedSecret = ref('');
const turnCredentialTtl = ref(3600);
const extensionForms = reactive({});
const newWebhookName = ref('');
const creatingWebhook = ref(false);
const savingWebhookId = ref(null);
const deletingWebhookId = ref(null);

const splitUrls = value =>
  value
    .split(/[\n,]/)
    .map(url => url.trim())
    .filter(Boolean);

const syncChannelForm = () => {
  wssUrl.value = props.inbox.wss_url || '';
  sipDomain.value = props.inbox.sip_domain || '';
  turnCredentialTtl.value = props.inbox.turn_credential_ttl || 3600;

  const urls = (props.inbox.ice_servers || []).flatMap(server =>
    Array.isArray(server.urls) ? server.urls : [server.urls]
  );
  stunUrls.value = urls
    .filter(url => url?.startsWith('stun:') || url?.startsWith('stuns:'))
    .join('\n');
  turnUrls.value = urls
    .filter(url => url?.startsWith('turn:') || url?.startsWith('turns:'))
    .join('\n');
};

watch(() => props.inbox, syncChannelForm, { immediate: true, deep: true });

const extensionByUserId = computed(() =>
  Object.fromEntries(
    extensions.value.map(extension => [extension.user_id, extension])
  )
);

const syncExtensionForms = () => {
  members.value.forEach(member => {
    const extension = extensionByUserId.value[member.id];
    extensionForms[member.id] = {
      sipUsername: extension?.sip_username || '',
      sipPassword: '',
      enabled: extension?.enabled ?? true,
    };
  });
};

const fetchConfiguration = async () => {
  try {
    const [memberResponse, extensionResponse, webhookResponse] =
      await Promise.all([
        store.dispatch('inboxMembers/get', { inboxId: props.inbox.id }),
        phoneExtensionsAPI.getAll(props.inbox.id),
        callbotWebhooksAPI.getAll(props.inbox.id),
      ]);
    members.value = memberResponse.data.payload;
    extensions.value = extensionResponse.data;
    callbotWebhooks.value = webhookResponse.data;
    syncExtensionForms();
  } catch (error) {
    useAlert(error.message);
  }
};

const saveChannel = async () => {
  const stun = splitUrls(stunUrls.value);
  const turn = splitUrls(turnUrls.value);
  if (turn.length && !props.inbox.turn_configured && !turnSharedSecret.value) {
    useAlert(t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.TURN_SECRET_REQUIRED'));
    return;
  }

  const iceServers = [];
  if (stun.length) iceServers.push({ urls: stun });
  if (turn.length) iceServers.push({ urls: turn });

  const channel = {
    wss_url: wssUrl.value.trim(),
    sip_domain: sipDomain.value.trim(),
    ice_servers: iceServers,
    turn_credential_ttl: Number(turnCredentialTtl.value),
  };
  if (turnSharedSecret.value) {
    channel.turn_shared_secret = turnSharedSecret.value;
  }

  isSavingChannel.value = true;
  try {
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      channel,
    });
    turnSharedSecret.value = '';
    useAlert(t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.CHANNEL_SAVED'));
  } catch (error) {
    useAlert(error.message);
  } finally {
    isSavingChannel.value = false;
  }
};

const saveExtension = async member => {
  const form = extensionForms[member.id];
  const existing = extensionByUserId.value[member.id];
  if (!form.sipUsername || (!existing && !form.sipPassword)) {
    useAlert(t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.EXTENSION_REQUIRED'));
    return;
  }

  const payload = {
    user_id: member.id,
    sip_username: form.sipUsername.trim(),
    enabled: form.enabled,
  };
  if (form.sipPassword) payload.sip_password = form.sipPassword;

  savingUserId.value = member.id;
  try {
    const response = existing
      ? await phoneExtensionsAPI.update(props.inbox.id, existing.id, payload)
      : await phoneExtensionsAPI.create(props.inbox.id, payload);
    extensions.value = [
      ...extensions.value.filter(extension => extension.user_id !== member.id),
      response.data,
    ];
    form.sipPassword = '';
    useAlert(t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.EXTENSION_SAVED'));
  } catch (error) {
    useAlert(error.message);
  } finally {
    savingUserId.value = null;
  }
};

const deleteExtension = async member => {
  const existing = extensionByUserId.value[member.id];
  if (!existing) return;

  deletingUserId.value = member.id;
  try {
    await phoneExtensionsAPI.delete(props.inbox.id, existing.id);
    extensions.value = extensions.value.filter(
      extension => extension.user_id !== member.id
    );
    extensionForms[member.id] = {
      sipUsername: '',
      sipPassword: '',
      enabled: true,
    };
    useAlert(t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.EXTENSION_DELETED'));
  } catch (error) {
    useAlert(error.message);
  } finally {
    deletingUserId.value = null;
  }
};

const createCallbotWebhook = async () => {
  if (!newWebhookName.value.trim()) return;
  creatingWebhook.value = true;
  try {
    const response = await callbotWebhooksAPI.create(props.inbox.id, {
      name: newWebhookName.value.trim(),
    });
    callbotWebhooks.value = [...callbotWebhooks.value, response.data];
    newWebhookName.value = '';
    useAlert(t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.WEBHOOK_CREATED'));
  } catch (error) {
    useAlert(error.message);
  } finally {
    creatingWebhook.value = false;
  }
};

const saveCallbotWebhook = async webhook => {
  savingWebhookId.value = webhook.id;
  try {
    const response = await callbotWebhooksAPI.update(
      props.inbox.id,
      webhook.id,
      {
        name: webhook.name,
        enabled: webhook.enabled,
      }
    );
    callbotWebhooks.value = callbotWebhooks.value.map(item =>
      item.id === webhook.id ? response.data : item
    );
    useAlert(t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.WEBHOOK_SAVED'));
  } catch (error) {
    useAlert(error.message);
  } finally {
    savingWebhookId.value = null;
  }
};

const deleteCallbotWebhook = async webhook => {
  deletingWebhookId.value = webhook.id;
  try {
    await callbotWebhooksAPI.delete(props.inbox.id, webhook.id);
    callbotWebhooks.value = callbotWebhooks.value.filter(
      item => item.id !== webhook.id
    );
    useAlert(t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.WEBHOOK_DELETED'));
  } catch (error) {
    useAlert(error.message);
  } finally {
    deletingWebhookId.value = null;
  }
};

onMounted(fetchConfiguration);
</script>

<template>
  <div class="flex flex-col gap-8">
    <section class="rounded-xl border border-n-weak bg-n-solid-2 p-6">
      <h3 class="text-heading-2 text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.CONNECTION_TITLE') }}
      </h3>
      <p class="mb-5 mt-1 text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.CONNECTION_DESC') }}
      </p>

      <form class="flex max-w-3xl flex-col gap-4" @submit.prevent="saveChannel">
        <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.PHONE_CHANNEL.WSS_URL') }}
          <input
            v-model="wssUrl"
            type="text"
            class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal"
          />
        </label>
        <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.PHONE_CHANNEL.SIP_DOMAIN') }}
          <input
            v-model="sipDomain"
            type="text"
            class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal"
          />
        </label>
        <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.STUN_URLS') }}
          <textarea
            v-model="stunUrls"
            rows="2"
            class="rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2 font-normal"
          />
        </label>
        <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.TURN_URLS') }}
          <textarea
            v-model="turnUrls"
            rows="2"
            class="rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2 font-normal"
          />
        </label>
        <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.TURN_SECRET') }}
          <input
            v-model="turnSharedSecret"
            type="password"
            autocomplete="new-password"
            class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal"
          />
          <span class="text-xs font-normal text-n-slate-10">
            {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.TURN_SECRET_HELP') }}
          </span>
        </label>
        <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.TURN_TTL') }}
          <input
            v-model.number="turnCredentialTtl"
            type="number"
            min="300"
            max="86400"
            class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal"
          />
        </label>
        <NextButton
          type="submit"
          solid
          blue
          class="self-start"
          :is-loading="isSavingChannel"
          :label="$t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.SAVE_CONNECTION')"
        />
      </form>
    </section>

    <section class="rounded-xl border border-n-weak bg-n-solid-2 p-6">
      <h3 class="text-heading-2 text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.EXTENSIONS_TITLE') }}
      </h3>
      <p class="mb-5 mt-1 text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.EXTENSIONS_DESC') }}
      </p>

      <div v-if="members.length" class="flex flex-col divide-y divide-n-weak">
        <div
          v-for="member in members"
          :key="member.id"
          class="grid gap-3 py-5 md:grid-cols-[minmax(10rem,1fr)_1fr_1fr_auto] md:items-end"
        >
          <div>
            <div class="font-medium text-n-slate-12">{{ member.name }}</div>
            <label class="mt-2 flex items-center gap-2 text-sm text-n-slate-11">
              <input
                v-model="extensionForms[member.id].enabled"
                type="checkbox"
              />
              {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.ENABLED') }}
            </label>
          </div>
          <label
            class="flex flex-col gap-1 text-sm font-medium text-n-slate-12"
          >
            {{ $t('INBOX_MGMT.ADD.PHONE_CHANNEL.SIP_USERNAME') }}
            <input
              v-model="extensionForms[member.id].sipUsername"
              type="text"
              class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal"
            />
          </label>
          <label
            class="flex flex-col gap-1 text-sm font-medium text-n-slate-12"
          >
            {{ $t('INBOX_MGMT.ADD.PHONE_CHANNEL.SIP_PASSWORD') }}
            <input
              v-model="extensionForms[member.id].sipPassword"
              type="password"
              autocomplete="new-password"
              :placeholder="
                $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.PASSWORD_PLACEHOLDER')
              "
              class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal"
            />
          </label>
          <div class="flex gap-2">
            <NextButton
              sm
              solid
              blue
              :is-loading="savingUserId === member.id"
              :label="$t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.SAVE_EXTENSION')"
              @click="saveExtension(member)"
            />
            <NextButton
              v-if="extensionByUserId[member.id]"
              sm
              ghost
              ruby
              :is-loading="deletingUserId === member.id"
              :label="$t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.DELETE_EXTENSION')"
              @click="deleteExtension(member)"
            />
          </div>
        </div>
      </div>
      <p v-else class="text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.NO_MEMBERS') }}
      </p>
    </section>

    <section class="rounded-xl border border-n-weak bg-n-solid-2 p-6">
      <h3 class="text-heading-2 text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.WEBHOOKS_TITLE') }}
      </h3>
      <p class="mb-5 mt-1 text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.WEBHOOKS_DESC') }}
      </p>

      <form
        class="mb-5 flex max-w-3xl gap-3"
        @submit.prevent="createCallbotWebhook"
      >
        <input
          v-model="newWebhookName"
          type="text"
          class="h-10 flex-1 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal"
          :placeholder="$t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.WEBHOOK_NAME')"
        />
        <NextButton
          type="submit"
          solid
          blue
          :is-loading="creatingWebhook"
          :label="$t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.CREATE_WEBHOOK')"
        />
      </form>

      <div
        v-if="callbotWebhooks.length"
        class="flex flex-col divide-y divide-n-weak"
      >
        <div
          v-for="webhook in callbotWebhooks"
          :key="webhook.id"
          class="grid gap-3 py-5 md:grid-cols-[minmax(10rem,1fr)_2fr_auto] md:items-end"
        >
          <label
            class="flex flex-col gap-1 text-sm font-medium text-n-slate-12"
          >
            {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.WEBHOOK_NAME') }}
            <input
              v-model="webhook.name"
              type="text"
              class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal"
            />
            <span
              class="mt-1 flex items-center gap-2 text-sm font-normal text-n-slate-11"
            >
              <input v-model="webhook.enabled" type="checkbox" />
              {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.ENABLED') }}
            </span>
          </label>
          <label
            class="flex flex-col gap-1 text-sm font-medium text-n-slate-12"
          >
            {{ $t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.WEBHOOK_URL') }}
            <input
              :value="webhook.endpoint_url"
              readonly
              type="text"
              class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal"
            />
          </label>
          <div class="flex gap-2">
            <NextButton
              sm
              solid
              blue
              :is-loading="savingWebhookId === webhook.id"
              :label="$t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.SAVE_WEBHOOK')"
              @click="saveCallbotWebhook(webhook)"
            />
            <NextButton
              sm
              ghost
              ruby
              :is-loading="deletingWebhookId === webhook.id"
              :label="$t('INBOX_MGMT.ADD.PHONE_CONFIGURATION.DELETE_WEBHOOK')"
              @click="deleteCallbotWebhook(webhook)"
            />
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
