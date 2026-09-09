# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Tekomi::Preferences', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  describe 'GET /api/v1/accounts/{account.id}/tekomi/preferences' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/tekomi/preferences",
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns tekomi config' do
        get "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        expect(json_response[:features]).not_to have_key(:conversation_completion)
      end
    end

    context 'when it is an admin' do
      it 'returns tekomi config' do
        get "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
      end

      it 'returns effective model provider and source for each feature' do
        account.update!(tekomi_models: { 'editor' => 'gpt-4.1' })

        get "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :editor)).to include(
          model: 'gpt-4.1',
          selected: 'gpt-4.1',
          provider: 'openai',
          source: 'account_override'
        )
        expect(json_response.dig(:features, :label_suggestion)).to include(
          model: Llm::Models.default_model_for('label_suggestion'),
          selected: Llm::Models.default_model_for('label_suggestion'),
          provider: 'openai',
          source: 'default'
        )
      end

      it 'returns the assistant YAML default for V1 accounts' do
        get "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :assistant)).to include(
          default: Llm::Models.default_model_for('assistant'),
          selected: Llm::Models.default_model_for('assistant'),
          source: 'default'
        )
      end

      it 'returns GPT-5.2 as the assistant default for V2 accounts' do
        account.enable_features!('tekomi_integration_v2')

        get "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :assistant)).to include(
          default: Llm::FeatureRouter::TEKOMI_V2_ASSISTANT_MODEL,
          selected: Llm::FeatureRouter::TEKOMI_V2_ASSISTANT_MODEL,
          source: 'default'
        )
      end

      it 'keeps the V2 assistant default when an account override is selected' do
        account.enable_features!('tekomi_integration_v2')
        account.update!(tekomi_models: { 'assistant' => 'gpt-5.1' })

        get "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :assistant)).to include(
          default: Llm::FeatureRouter::TEKOMI_V2_ASSISTANT_MODEL,
          selected: 'gpt-5.1',
          source: 'account_override'
        )
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/tekomi/preferences' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            params: { tekomi_models: { editor: 'gpt-4.1-mini' } },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns forbidden' do
        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: agent.create_new_auth_token,
            params: { tekomi_models: { editor: 'gpt-4.1-mini' } },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      it 'updates tekomi_models' do
        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            params: { tekomi_models: { editor: 'gpt-4.1-mini' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        expect(account.reload.tekomi_models['editor']).to eq('gpt-4.1-mini')
      end

      it 'does not persist unknown or internal tekomi model feature keys' do
        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            params: {
              tekomi_models: {
                editor: 'gpt-4.1-mini',
                unknown_feature: 'gpt-4.1',
                conversation_completion: 'gpt-4.1'
              }
            },
            as: :json

        expect(response).to have_http_status(:success)
        expect(account.reload.tekomi_models).to eq('editor' => 'gpt-4.1-mini')
        expect(json_response[:features]).not_to have_key(:conversation_completion)
      end

      it 'rejects invalid tekomi model values for the feature' do
        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            params: { tekomi_models: { label_suggestion: 'gpt-5.1' } },
            as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:message]).to include('not a valid model for label_suggestion')
        expect(account.reload.tekomi_models).to be_nil
      end

      it 'removes blank tekomi model overrides' do
        account.update!(tekomi_models: { 'editor' => 'gpt-4.1' })

        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            params: { tekomi_models: { editor: '' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(account.reload.tekomi_models).to be_nil
        expect(json_response.dig(:features, :editor)).to include(
          selected: Llm::Models.default_model_for('editor'),
          source: 'default'
        )
      end

      it 'updates tekomi_models for document FAQ generation' do
        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            params: { tekomi_models: { document_faq_generation: 'gpt-5.2' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :document_faq_generation, :selected)).to eq('gpt-5.2')
        expect(account.reload.tekomi_models['document_faq_generation']).to eq('gpt-5.2')
      end

      it 'updates tekomi_models for conversation FAQ generation' do
        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            params: { tekomi_models: { conversation_faq_generation: 'gpt-4.1-mini' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :conversation_faq_generation, :selected)).to eq('gpt-4.1-mini')
        expect(account.reload.tekomi_models['conversation_faq_generation']).to eq('gpt-4.1-mini')
      end

      it 'updates tekomi_models for PDF FAQ generation' do
        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            params: { tekomi_models: { pdf_faq_generation: 'gpt-5.2' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response.dig(:features, :pdf_faq_generation, :selected)).to eq('gpt-5.2')
        expect(account.reload.tekomi_models['pdf_faq_generation']).to eq('gpt-5.2')
      end

      it 'updates tekomi_features' do
        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            params: { tekomi_features: { editor: true } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        expect(account.reload.tekomi_features['editor']).to be true
      end

      it 'merges with existing tekomi_models' do
        account.update!(tekomi_models: { 'editor' => 'gpt-4.1-mini', 'assistant' => 'gpt-5.1' })

        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            params: { tekomi_models: { editor: 'gpt-4.1' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        models = account.reload.tekomi_models
        expect(models['editor']).to eq('gpt-4.1')
        expect(models['assistant']).to eq('gpt-5.1') # Preserved
      end

      it 'merges with existing tekomi_features' do
        account.update!(tekomi_features: { 'editor' => true, 'assistant' => false })

        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            params: { tekomi_features: { editor: false } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        features = account.reload.tekomi_features
        expect(features['editor']).to be false
        expect(features['assistant']).to be false # Preserved
      end

      it 'updates both models and features in single request' do
        put "/api/v1/accounts/#{account.id}/tekomi/preferences",
            headers: admin.create_new_auth_token,
            params: {
              tekomi_models: { editor: 'gpt-4.1-mini' },
              tekomi_features: { editor: true }
            },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        account.reload
        expect(account.tekomi_models['editor']).to eq('gpt-4.1-mini')
        expect(account.tekomi_features['editor']).to be true
      end
    end
  end
end
