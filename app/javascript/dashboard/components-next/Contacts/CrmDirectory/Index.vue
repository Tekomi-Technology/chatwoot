<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useRouter } from 'vue-router';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import CompanyAPI from 'dashboard/api/companies';
import ContactAPI from 'dashboard/api/contacts';

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const companies = ref([]);
const ungroupedContacts = ref([]);
const expandedIds = ref(new Set());
const companyContacts = ref({});
const isLoading = ref(true);
const isSyncing = ref(false);

const ungroupedExpanded = ref(false);

const totalContacts = computed(
  () =>
    companies.value.reduce(
      (sum, company) => sum + (company.contacts_count || 0),
      0
    ) + ungroupedContacts.value.length
);

const crmBadge = contact => {
  const attrs = contact.additional_attributes || {};
  return attrs.external?.perfex_contact_id ? 'CRM' : '';
};

const fetchCompanies = async () => {
  let page = 1;
  const all = [];
  // paginate defensively; accounts are small so this converges quickly
  for (;;) {
    const { data } = await CompanyAPI.get({ page });
    const rows = data.payload || data || [];
    all.push(...rows);
    if (rows.length < 15 || page > 50) break;
    page += 1;
  }
  companies.value = all;
};

const fetchUngrouped = async () => {
  let page = 1;
  const all = [];
  for (;;) {
    const { data } = await ContactAPI.getWithParams({
      page,
      company_id: 'none',
    });
    const rows = data.payload || data || [];
    all.push(...rows);
    if (rows.length < 15 || page > 50) break;
    page += 1;
  }
  ungroupedContacts.value = all;
};

const loadAll = async () => {
  isLoading.value = true;
  try {
    await Promise.all([fetchCompanies(), fetchUngrouped()]);
  } catch (error) {
    useAlert(error.message);
  } finally {
    isLoading.value = false;
  }
};

const toggleCompany = async company => {
  const id = company.id;
  if (expandedIds.value.has(id)) {
    expandedIds.value.delete(id);
    expandedIds.value = new Set(expandedIds.value);
    return;
  }
  expandedIds.value = new Set([...expandedIds.value, id]);
  if (!companyContacts.value[id]) {
    try {
      const { data } = await CompanyAPI.listContacts(id);
      companyContacts.value = {
        ...companyContacts.value,
        [id]: data.payload || data || [],
      };
    } catch (error) {
      useAlert(error.message);
    }
  }
};

const openContact = contact => {
  router.push({
    name: 'contacts_edit',
    params: { contactId: contact.id },
  });
};

const syncCrm = async () => {
  isSyncing.value = true;
  try {
    const response = await store.dispatch('contacts/crmForceSync');
    const age = response?.cache_age_minutes;
    useAlert(
      age === null || age === undefined
        ? t('CRM_DIRECTORY.SYNC_STARTED_FIRST_TIME')
        : t('CRM_DIRECTORY.SYNC_STARTED', { age })
    );
    await loadAll();
  } catch (error) {
    useAlert(error.message);
  } finally {
    isSyncing.value = false;
  }
};

onMounted(loadAll);
</script>

<template>
  <div
    class="flex flex-col flex-1 overflow-y-auto px-6 py-6 w-full mx-auto max-w-5xl"
  >
    <header class="flex items-center justify-between mb-4">
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ $t('CRM_DIRECTORY.TITLE') }}
      </h1>
      <NextButton
        size="sm"
        :is-loading="isSyncing"
        :label="$t('CRM_DIRECTORY.SYNC_BUTTON')"
        @click="syncCrm"
      />
    </header>

    <p class="mb-4 text-sm text-n-slate-11">
      {{ $t('CRM_DIRECTORY.SUBTITLE', { count: totalContacts }) }}
    </p>

    <div v-if="isLoading" class="text-sm text-n-slate-11 py-8 text-center">
      {{ $t('CRM_DIRECTORY.LOADING') }}
    </div>
    <template v-else>
      <div
        v-for="company in companies"
        :key="company.id"
        class="border border-n-weak rounded-lg mb-2 overflow-hidden bg-n-solid-1"
      >
        <button
          class="flex w-full items-center gap-2 px-4 py-3 text-left hover:bg-n-alpha-1"
          @click="toggleCompany(company)"
        >
          <Icon
            :icon="
              expandedIds.has(company.id)
                ? 'i-lucide-chevron-down'
                : 'i-lucide-chevron-right'
            "
            class="size-4 text-n-slate-11"
          />
          <Icon icon="i-lucide-building-2" class="size-4 text-n-slate-11" />
          <span class="text-sm font-medium truncate text-n-slate-12">
            {{ company.name }}
          </span>
          <span class="text-xs text-n-slate-11 ms-auto">
            {{ company.contacts_count || 0 }}
          </span>
        </button>
        <div
          v-if="expandedIds.has(company.id)"
          class="border-t border-n-weak bg-n-background"
        >
          <div
            v-for="contact in companyContacts[company.id] || []"
            :key="contact.id"
            class="flex items-center gap-3 px-10 py-2 hover:bg-n-alpha-1 cursor-pointer"
            @click="openContact(contact)"
          >
            <span class="text-sm text-n-slate-12 truncate">
              {{ contact.name }}
            </span>
            <span class="text-xs text-n-slate-11 truncate">
              {{ contact.phone_number || contact.email }}
            </span>
            <span
              v-if="crmBadge(contact)"
              class="ms-auto text-xs text-n-teal-11 flex-shrink-0"
            >
              {{ crmBadge(contact) }}
            </span>
          </div>
          <p
            v-if="!(companyContacts[company.id] || []).length"
            class="px-10 py-2 text-xs text-n-slate-11"
          >
            {{ $t('CRM_DIRECTORY.NO_CONTACTS') }}
          </p>
        </div>
      </div>

      <div
        class="border border-n-weak rounded-lg mb-2 overflow-hidden bg-n-solid-1"
      >
        <button
          class="flex w-full items-center gap-2 px-4 py-3 text-left hover:bg-n-alpha-1"
          @click="ungroupedExpanded = !ungroupedExpanded"
        >
          <Icon
            :icon="
              ungroupedExpanded
                ? 'i-lucide-chevron-down'
                : 'i-lucide-chevron-right'
            "
            class="size-4 text-n-slate-11"
          />
          <span class="text-sm font-medium text-n-slate-12">
            {{ $t('CRM_DIRECTORY.UNGROUPED') }}
          </span>
          <span class="text-xs text-n-slate-11 ms-auto">
            {{ ungroupedContacts.length }}
          </span>
        </button>
        <div
          v-if="ungroupedExpanded"
          class="border-t border-n-weak bg-n-background"
        >
          <div
            v-for="contact in ungroupedContacts"
            :key="contact.id"
            class="flex items-center gap-3 px-10 py-2 hover:bg-n-alpha-1 cursor-pointer"
            @click="openContact(contact)"
          >
            <span class="text-sm text-n-slate-12 truncate">
              {{ contact.name }}
            </span>
            <span class="text-xs text-n-slate-11 truncate">
              {{ contact.phone_number || contact.email }}
            </span>
            <span
              v-if="crmBadge(contact)"
              class="ms-auto text-xs text-n-teal-11 flex-shrink-0"
            >
              {{ crmBadge(contact) }}
            </span>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
