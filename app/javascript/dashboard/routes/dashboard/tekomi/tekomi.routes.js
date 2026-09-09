import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import {
  CONVERSATION_PERMISSIONS,
  ROLES,
} from 'dashboard/constants/permissions';
import { frontendURL } from '../../../helper/URLHelper';

import TekomiPageRouteView from './pages/TekomiPageRouteView.vue';
import AssistantsIndexPage from './pages/AssistantsIndexPage.vue';
import AssistantEmptyStateIndex from './assistants/Index.vue';

import AssistantOverviewIndex from './assistants/overview/Index.vue';
import AssistantSettingsIndex from './assistants/settings/Index.vue';
import AssistantSystemSettingsIndex from './assistants/settings/System.vue';
import AssistantAudienceSettingsIndex from './assistants/settings/Audience.vue';
import AssistantScheduleSettingsIndex from './assistants/settings/Schedule.vue';
import AssistantInboxesIndex from './assistants/inboxes/Index.vue';
import AssistantPlaygroundIndex from './assistants/playground/Index.vue';
import AssistantGuardrailsIndex from './assistants/guardrails/Index.vue';
import AssistantGuidelinesIndex from './assistants/guidelines/Index.vue';
import AssistantScenariosIndex from './assistants/scenarios/Index.vue';
import DocumentsIndex from './documents/Index.vue';
import ResponsesIndex from './responses/Index.vue';
import FaqSuggestionsIndex from './responses/FaqSuggestions.vue';
import CustomToolsIndex from './tools/Index.vue';

const meta = {
  permissions: ['administrator', 'agent'],
  featureFlag: FEATURE_FLAGS.TEKOMI,
  installationTypes: [INSTALLATION_TYPES.CLOUD, INSTALLATION_TYPES.ENTERPRISE],
};

const faqSuggestionsMeta = {
  ...meta,
  permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
};

const metaCustomTools = {
  permissions: ['administrator', 'agent'],
  featureFlag: FEATURE_FLAGS.TEKOMI_CUSTOM_TOOLS,
  installationTypes: [INSTALLATION_TYPES.CLOUD, INSTALLATION_TYPES.ENTERPRISE],
};

const metaV2 = {
  permissions: ['administrator', 'agent'],
  featureFlag: FEATURE_FLAGS.TEKOMI_V2,
  installationTypes: [INSTALLATION_TYPES.CLOUD, INSTALLATION_TYPES.ENTERPRISE],
};

const assistantRoutes = [
  {
    path: frontendURL('accounts/:accountId/tekomi/:assistantId/overview'),
    component: AssistantOverviewIndex,
    name: 'tekomi_assistants_overview_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/tekomi/:assistantId/faqs'),
    component: ResponsesIndex,
    name: 'tekomi_assistants_responses_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/tekomi/:assistantId/documents'),
    component: DocumentsIndex,
    name: 'tekomi_assistants_documents_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/tekomi/:assistantId/tools'),
    component: CustomToolsIndex,
    name: 'tekomi_tools_index',
    meta: metaCustomTools,
  },
  {
    path: frontendURL('accounts/:accountId/tekomi/:assistantId/scenarios'),
    component: AssistantScenariosIndex,
    name: 'tekomi_assistants_scenarios_index',
    meta: metaV2,
  },
  {
    path: frontendURL('accounts/:accountId/tekomi/:assistantId/playground'),
    component: AssistantPlaygroundIndex,
    name: 'tekomi_assistants_playground_index',
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/tekomi/:assistantId/inboxes'),
    component: AssistantInboxesIndex,
    name: 'tekomi_assistants_inboxes_index',
    meta,
  },
  {
    path: frontendURL(
      'accounts/:accountId/tekomi/:assistantId/faqs/suggestions'
    ),
    component: FaqSuggestionsIndex,
    name: 'tekomi_assistants_faq_suggestions',
    meta: faqSuggestionsMeta,
  },
  {
    path: frontendURL('accounts/:accountId/tekomi/:assistantId/faqs/pending'),
    redirect: to => ({
      name: 'tekomi_assistants_faq_suggestions',
      params: to.params,
      query: to.query,
    }),
  },
  {
    path: frontendURL('accounts/:accountId/tekomi/:assistantId/settings'),
    component: AssistantSettingsIndex,
    name: 'tekomi_assistants_settings_index',
    meta,
  },
  // Settings sub-pages
  {
    path: frontendURL(
      'accounts/:accountId/tekomi/:assistantId/settings/system'
    ),
    component: AssistantSystemSettingsIndex,
    name: 'tekomi_assistants_settings_system_index',
    meta,
  },
  {
    path: frontendURL(
      'accounts/:accountId/tekomi/:assistantId/settings/audience'
    ),
    component: AssistantAudienceSettingsIndex,
    name: 'tekomi_assistants_settings_audience_index',
    meta,
  },
  {
    path: frontendURL(
      'accounts/:accountId/tekomi/:assistantId/settings/schedule'
    ),
    component: AssistantScheduleSettingsIndex,
    name: 'tekomi_assistants_settings_schedule_index',
    meta,
  },
  {
    path: frontendURL(
      'accounts/:accountId/tekomi/:assistantId/settings/guardrails'
    ),
    component: AssistantGuardrailsIndex,
    name: 'tekomi_assistants_guardrails_index',
    meta: metaV2,
  },
  {
    path: frontendURL(
      'accounts/:accountId/tekomi/:assistantId/settings/guidelines'
    ),
    component: AssistantGuidelinesIndex,
    name: 'tekomi_assistants_guidelines_index',
    meta: metaV2,
  },
  {
    path: frontendURL('accounts/:accountId/tekomi/assistants'),
    component: AssistantEmptyStateIndex,
    name: 'tekomi_assistants_create_index',
    meta: {
      permissions: ['administrator', 'agent'],
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
      ],
    },
  },
  {
    path: frontendURL('accounts/:accountId/tekomi/:navigationPath'),
    component: AssistantsIndexPage,
    name: 'tekomi_assistants_index',
    meta,
  },
];

export const routes = [
  {
    path: frontendURL('accounts/:accountId/tekomi'),
    component: TekomiPageRouteView,
    redirect: to => {
      return {
        name: 'tekomi_assistants_index',
        params: {
          navigationPath: 'tekomi_assistants_overview_index',
          ...to.params,
        },
      };
    },
    children: [...assistantRoutes],
  },
];
