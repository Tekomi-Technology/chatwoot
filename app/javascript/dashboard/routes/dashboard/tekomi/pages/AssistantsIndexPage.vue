<script setup>
import { computed, nextTick, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useUISettings } from 'dashboard/composables/useUISettings';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const store = useStore();
const router = useRouter();
const { uiSettings } = useUISettings();
const route = useRoute();

const assistants = computed(() => store.getters['tekomiAssistants/getRecords']);

const isAssistantPresent = assistantId => {
  return !!assistants.value.find(a => a.id === Number(assistantId));
};

const routeToView = (name, params) => {
  router.replace({ name, params, replace: true });
};

const generateRouterParams = () => {
  const { last_active_assistant_id: lastActiveAssistantId } =
    uiSettings.value || {};

  if (isAssistantPresent(lastActiveAssistantId)) {
    return {
      assistantId: lastActiveAssistantId,
    };
  }

  if (assistants.value.length > 0) {
    const { id: assistantId } = assistants.value[0];
    return { assistantId };
  }

  return null;
};

const routeToLastActiveAssistant = () => {
  const params = generateRouterParams();

  // No assistants found, redirect to create page
  if (!params) {
    return routeToView('tekomi_assistants_create_index', {
      accountId: route.params.accountId,
    });
  }

  const { navigationPath } = route.params;
  const isAValidRoute = [
    'tekomi_assistants_overview_index', // Overview page
    'tekomi_assistants_responses_index', // Faq page
    'tekomi_assistants_documents_index', // Document page
    'tekomi_assistants_scenarios_index', // Scenario page
    'tekomi_assistants_playground_index', // Playground page
    'tekomi_assistants_inboxes_index', // Inboxes page
    'tekomi_tools_index', // Tools page
    'tekomi_assistants_settings_index', // Settings page
  ].includes(navigationPath);

  const navigateTo = isAValidRoute
    ? navigationPath
    : 'tekomi_assistants_overview_index';

  return routeToView(navigateTo, {
    accountId: route.params.accountId,
    ...params,
  });
};

const performRouting = async () => {
  await store.dispatch('tekomiAssistants/get');
  nextTick(() => routeToLastActiveAssistant());
};

onMounted(() => performRouting());
</script>

<template>
  <div
    class="flex items-center justify-center w-full bg-n-surface-1 text-n-slate-11"
  >
    <Spinner />
  </div>
</template>
