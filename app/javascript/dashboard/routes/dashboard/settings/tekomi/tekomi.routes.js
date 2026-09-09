import { frontendURL } from '../../../../helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/tekomi'),
      meta: {
        permissions: ['administrator'],
        featureFlag: FEATURE_FLAGS.TEKOMI,
      },
      component: SettingsWrapper,
      props: {
        headerTitle: 'TEKOMI_SETTINGS.TITLE',
        icon: 'i-lucide-bot',
        showNewButton: false,
      },
      children: [
        {
          path: '',
          name: 'tekomi_settings_index',
          component: Index,
          meta: {
            permissions: ['administrator'],
            featureFlag: FEATURE_FLAGS.TEKOMI,
            installationTypes: [
              INSTALLATION_TYPES.ENTERPRISE,
              INSTALLATION_TYPES.CLOUD,
            ],
          },
        },
      ],
    },
  ],
};
