<script setup>
import { computed, h, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { picoSearch } from '@chatwoot/pico-search';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

import PageLayout from 'dashboard/components-next/tekomi/PageLayout.vue';
import SettingsHeader from 'dashboard/components-next/tekomi/pageComponents/settings/SettingsHeader.vue';
import SuggestedScenarios from 'dashboard/components-next/tekomi/assistant/SuggestedRules.vue';
import ScenariosCard from 'dashboard/components-next/tekomi/assistant/ScenariosCard.vue';
import BulkSelectBar from 'dashboard/components-next/tekomi/assistant/BulkSelectBar.vue';
import AddNewScenariosDialog from 'dashboard/components-next/tekomi/assistant/AddNewScenariosDialog.vue';

const { t } = useI18n();
const route = useRoute();
const store = useStore();
const { uiSettings, updateUISettings } = useUISettings();
const { formatMessage } = useMessageFormatter();
const assistantId = computed(() => Number(route.params.assistantId));

const uiFlags = useMapGetter('tekomiScenarios/getUIFlags');
const isFetching = computed(() => uiFlags.value.fetchingList);
const scenarios = useMapGetter('tekomiScenarios/getRecords');

const searchQuery = ref('');

const LINK_INSTRUCTION_CLASS =
  '[&_a[href^="tool://"]]:text-n-iris-11 [&_a:not([href^="tool://"])]:text-n-slate-12 [&_a]:pointer-events-none [&_a]:cursor-default';

const renderInstruction = instruction => () =>
  h('span', {
    class: `text-sm text-n-slate-12 py-4 prose prose-sm min-w-0 break-words ${LINK_INSTRUCTION_CLASS}`,
    innerHTML: instruction,
  });

// Suggested example scenarios for quick add
const scenariosExample = [
  {
    id: 1,
    title: 'Khách hàng tiềm năng',
    description: 'Xử lý khách hàng đang quan tâm mua license',
    instruction:
      'Nếu có khách hàng quan tâm mua license, hỏi họ những thông tin sau:\n\n1. Họ muốn mua bao nhiêu license?\n2. Họ có đang chuyển từ nền tảng khác sang không?\n. Sau khi thu thập đủ thông tin, thực hiện các bước sau\n1. Thêm ghi chú nội bộ với thông tin đã thu thập bằng [Add Private Note](tool://add_private_note)\n2. Gắn nhãn "sales" cho liên hệ bằng [Add Label to Conversation](tool://add_label_to_conversation)\n3. Trả lời rằng "sẽ có người liên hệ lại sớm" kèm thời gian phản hồi dự kiến, và [Handoff to Human](tool://handoff)',
    tools: ['add_private_note', 'add_label_to_conversation', 'handoff'],
  },
];

const filteredScenarios = computed(() => {
  const query = searchQuery.value.trim();
  const source = scenarios.value;
  if (!query) return source;
  return picoSearch(source, query, ['title', 'description', 'instruction']);
});

const shouldShowSuggestedRules = computed(() => {
  return uiSettings.value?.show_scenarios_suggestions !== false;
});

const closeSuggestedRules = () => {
  updateUISettings({ show_scenarios_suggestions: false });
};

// Bulk selection & hover state
const bulkSelectedIds = ref(new Set());
const hoveredCard = ref(null);

const handleRuleSelect = id => {
  const selected = new Set(bulkSelectedIds.value);
  selected[selected.has(id) ? 'delete' : 'add'](id);
  bulkSelectedIds.value = selected;
};

const buildSelectedCountLabel = computed(() => {
  const count = scenarios.value.length || 0;
  const isAllSelected = bulkSelectedIds.value.size === count && count > 0;
  return isAllSelected
    ? t('TEKOMI.ASSISTANTS.SCENARIOS.BULK_ACTION.UNSELECT_ALL', { count })
    : t('TEKOMI.ASSISTANTS.SCENARIOS.BULK_ACTION.SELECT_ALL', { count });
});

const selectedCountLabel = computed(() => {
  return t('TEKOMI.ASSISTANTS.SCENARIOS.BULK_ACTION.SELECTED', {
    count: bulkSelectedIds.value.size,
  });
});

const handleRuleHover = (isHovered, id) => {
  hoveredCard.value = isHovered ? id : null;
};

const getToolsFromInstruction = instruction => [
  ...new Set(
    [...(instruction?.matchAll(/\(tool:\/\/([^)]+)\)/g) ?? [])].map(m => m[1])
  ),
];

const updateScenario = async scenario => {
  try {
    await store.dispatch('tekomiScenarios/update', {
      id: scenario.id,
      assistantId: assistantId.value,
      ...scenario,
      tools: getToolsFromInstruction(scenario.instruction),
    });
    useAlert(t('TEKOMI.ASSISTANTS.SCENARIOS.API.UPDATE.SUCCESS'));
  } catch (error) {
    const errorMessage =
      error?.response?.message ||
      t('TEKOMI.ASSISTANTS.SCENARIOS.API.UPDATE.ERROR');
    useAlert(errorMessage);
  }
};

const deleteScenario = async id => {
  try {
    await store.dispatch('tekomiScenarios/delete', {
      id,
      assistantId: assistantId.value,
    });
    useAlert(t('TEKOMI.ASSISTANTS.SCENARIOS.API.DELETE.SUCCESS'));
  } catch (error) {
    const errorMessage =
      error?.response?.message ||
      t('TEKOMI.ASSISTANTS.SCENARIOS.API.DELETE.ERROR');
    useAlert(errorMessage);
  }
};

// TODO: Add bulk delete endpoint
const bulkDeleteScenarios = async ids => {
  const idsArray = ids || Array.from(bulkSelectedIds.value);
  await Promise.all(
    idsArray.map(id =>
      store.dispatch('tekomiScenarios/delete', {
        id,
        assistantId: assistantId.value,
      })
    )
  );
  bulkSelectedIds.value = new Set();
  useAlert(t('TEKOMI.ASSISTANTS.SCENARIOS.API.DELETE.SUCCESS'));
};

const addScenario = async scenario => {
  try {
    await store.dispatch('tekomiScenarios/create', {
      assistantId: assistantId.value,
      ...scenario,
      tools: getToolsFromInstruction(scenario.instruction),
    });
    useAlert(t('TEKOMI.ASSISTANTS.SCENARIOS.API.ADD.SUCCESS'));
  } catch (error) {
    const errorMessage =
      error?.response?.message ||
      t('TEKOMI.ASSISTANTS.SCENARIOS.API.ADD.ERROR');
    useAlert(errorMessage);
  }
};

const addAllExampleScenarios = async () => {
  try {
    scenariosExample.forEach(async scenario => {
      await store.dispatch('tekomiScenarios/create', {
        assistantId: assistantId.value,
        ...scenario,
      });
    });
    useAlert(t('TEKOMI.ASSISTANTS.SCENARIOS.API.ADD.SUCCESS'));
  } catch (error) {
    const errorMessage =
      error?.response?.message ||
      t('TEKOMI.ASSISTANTS.SCENARIOS.API.ADD.ERROR');
    useAlert(errorMessage);
  }
};

onMounted(() => {
  store.dispatch('tekomiScenarios/get', {
    assistantId: assistantId.value,
  });
  store.dispatch('tekomiTools/getTools');
});
</script>

<template>
  <PageLayout
    :header-title="$t('TEKOMI.ASSISTANTS.SCENARIOS.TITLE')"
    :is-fetching="isFetching"
    :show-know-more="false"
    :show-pagination-footer="false"
  >
    <template #body>
      <SettingsHeader
        :heading="$t('TEKOMI.ASSISTANTS.SCENARIOS.TITLE')"
        :description="$t('TEKOMI.ASSISTANTS.SCENARIOS.DESCRIPTION')"
      />
      <div v-if="shouldShowSuggestedRules" class="flex mt-7 flex-col gap-4">
        <SuggestedScenarios
          :title="$t('TEKOMI.ASSISTANTS.SCENARIOS.ADD.SUGGESTED.TITLE')"
          :items="scenariosExample"
          @close="closeSuggestedRules"
          @add="addAllExampleScenarios"
        >
          <template #default="{ item }">
            <div class="flex items-center gap-3 justify-between">
              <span class="text-sm text-n-slate-12">
                {{ item.title }}
              </span>
              <Button
                :label="
                  $t('TEKOMI.ASSISTANTS.SCENARIOS.ADD.SUGGESTED.ADD_SINGLE')
                "
                ghost
                xs
                slate
                class="!text-sm !text-n-slate-11 flex-shrink-0"
                @click="addScenario(item)"
              />
            </div>
            <div class="flex flex-col">
              <span class="text-sm text-n-slate-11 mt-2">
                {{ item.description }}
              </span>
              <component
                :is="renderInstruction(formatMessage(item.instruction, false))"
              />
              <span class="text-sm text-n-slate-11 font-medium mb-1">
                {{ t('TEKOMI.ASSISTANTS.SCENARIOS.ADD.SUGGESTED.TOOLS_USED') }}
                {{ item.tools?.map(tool => `@${tool}`).join(', ') }}
              </span>
            </div>
          </template>
        </SuggestedScenarios>
      </div>
      <div class="flex mt-7 flex-col gap-4">
        <div class="flex justify-between items-center">
          <BulkSelectBar
            v-model="bulkSelectedIds"
            :all-items="scenarios"
            :select-all-label="buildSelectedCountLabel"
            :selected-count-label="selectedCountLabel"
            :delete-label="
              $t('TEKOMI.ASSISTANTS.SCENARIOS.BULK_ACTION.BULK_DELETE_BUTTON')
            "
            @bulk-delete="bulkDeleteScenarios"
          >
            <template #default-actions>
              <AddNewScenariosDialog @add="addScenario" />
            </template>
          </BulkSelectBar>
          <div
            v-if="scenarios.length && bulkSelectedIds.size === 0"
            class="max-w-[22.5rem] w-full min-w-0"
          >
            <Input
              v-model="searchQuery"
              :placeholder="
                t('TEKOMI.ASSISTANTS.SCENARIOS.LIST.SEARCH_PLACEHOLDER')
              "
            />
          </div>
        </div>
        <div v-if="scenarios.length === 0" class="mt-1 mb-2">
          <span class="text-n-slate-11 text-sm">
            {{ t('TEKOMI.ASSISTANTS.SCENARIOS.EMPTY_MESSAGE') }}
          </span>
        </div>
        <div v-else-if="filteredScenarios.length === 0" class="mt-1 mb-2">
          <span class="text-n-slate-11 text-sm">
            {{ t('TEKOMI.ASSISTANTS.SCENARIOS.SEARCH_EMPTY_MESSAGE') }}
          </span>
        </div>
        <div v-else class="flex flex-col gap-2">
          <ScenariosCard
            v-for="scenario in filteredScenarios"
            :id="scenario.id"
            :key="scenario.id"
            :title="scenario.title"
            :description="scenario.description"
            :instruction="scenario.instruction"
            :tools="scenario.tools"
            :is-selected="bulkSelectedIds.has(scenario.id)"
            :selectable="
              hoveredCard === scenario.id || bulkSelectedIds.size > 0
            "
            @select="handleRuleSelect"
            @delete="deleteScenario(scenario.id)"
            @update="updateScenario"
            @hover="isHovered => handleRuleHover(isHovered, scenario.id)"
          />
        </div>
      </div>
    </template>
  </PageLayout>
</template>
