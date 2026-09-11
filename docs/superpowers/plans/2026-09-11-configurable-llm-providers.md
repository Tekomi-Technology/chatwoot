# Cấu hình Provider & Model AI từ Super Admin — Kế hoạch triển khai

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bỏ hardcode provider/model AI; Super Admin cấu hình nhiều provider và chọn provider + model cho từng tính năng AI.

**Architecture:** Hai bảng `llm_providers` (key mã hóa) và `llm_feature_models`. Mọi điểm gọi AI đi qua `Llm::FeatureRouter.resolve(feature:)` → trả `{ provider:, model: }`, đồng thời `Llm::Config.apply!` nạp key/endpoint vào cấu hình RubyLLM toàn cục (nạp lại khi khóa phiên bản trong Redis đổi). Mọi request RubyLLM truyền `provider:` + `assume_model_exists: true`.

**Tech Stack:** Rails 7.2, RubyLLM 1.15, ai-agents 0.12.0, Administrate (Super Admin ERB), Vue 3 + Pinia.

**Spec:** `docs/superpowers/specs/2026-09-11-configurable-llm-providers-design.md`

## Global Constraints

- Không viết spec mới, không có bước chạy test — người dùng tự kiểm thử.
- **Không commit.** Không có bước commit trong kế hoạch; người dùng tự quyết định commit.
- Không thêm comment mô tả vào code mới.
- i18n: chỉ sửa `config/locales/en.yml` và `app/javascript/dashboard/i18n/locale/en/*.json`.
- Ruby: RuboCop, tối đa 150 ký tự/dòng, `module/class` dạng compact (`class Foo::Bar`).
- Vue: Composition API `<script setup>`, Tailwind, không CSS riêng.
- Không fallback model/provider khi chưa cấu hình → `CustomExceptions::Llm::FeatureNotConfigured`.
- Mỗi `provider_type` tối đa 1 dòng (ai-agents chỉ đọc cấu hình RubyLLM toàn cục).
- Embedding giữ 1536 chiều.
- Chạy trong worktree `.claude/worktrees/configurable-llm-providers`, nhánh `feature/configurable-llm-providers`.
- Các Task 1–8 làm hỏng lời gọi cũ tạm thời (đổi chữ ký `FeatureRouter.resolve`, `BaseAiService`, `make_api_call`); chỉ khởi động app sau khi xong Task 12.
- Máy local chưa có Ruby 3.4.4: các lệnh `bundle`/`rails` chạy trong môi trường có Ruby (rbenv hoặc Docker).

## File Structure

| File | Trách nhiệm |
|---|---|
| `db/migrate/20260911000001_create_llm_providers_and_feature_models.rb` | Tạo 2 bảng |
| `db/migrate/20260911000002_move_tekomi_llm_config_to_llm_providers.rb` | Chuyển cấu hình cũ, dọn dữ liệu cũ |
| `app/models/llm_provider.rb` | Provider + validation + mã hóa key + bump phiên bản cấu hình |
| `app/models/llm_feature_model.rb` | Tính năng → provider + model |
| `config/llm.yml` | Danh sách tính năng + nhóm |
| `lib/llm/features.rb` (thay `lib/llm/models.rb`) | Đọc danh sách tính năng |
| `lib/llm/feature_router.rb` | Resolve tính năng → `{ feature:, provider:, model: }` |
| `lib/llm/config.rb` | Nạp provider vào RubyLLM toàn cục theo phiên bản |
| `lib/custom_exceptions/llm.rb` | `FeatureNotConfigured` |
| `enterprise/app/controllers/super_admin/llm_providers_controller.rb` | CRUD provider |
| `enterprise/app/controllers/super_admin/llm_feature_models_controller.rb` | Bảng tính năng AI |
| `enterprise/app/views/super_admin/llm_providers/*` | Tabs, danh sách, form provider |
| `enterprise/app/views/super_admin/llm_feature_models/show.html.erb` | Bảng tính năng AI |

---

### Task 1: Dữ liệu, danh sách tính năng, exception

**Files:**
- Create: `db/migrate/20260911000001_create_llm_providers_and_feature_models.rb`
- Create: `app/models/llm_provider.rb`
- Create: `app/models/llm_feature_model.rb`
- Create: `lib/llm/features.rb`
- Delete: `lib/llm/models.rb`
- Modify: `config/llm.yml` (thay toàn bộ)
- Create: `lib/custom_exceptions/llm.rb`
- Modify: `config/locales/en.yml` (khối `errors:`)

**Interfaces:**
- Produces: `LlmProvider::PROVIDER_TYPES`, `LlmProvider#masked_api_key`, `LlmProvider#llm_feature_models`, `LlmFeatureModel#llm_provider`, `Llm::Features.keys` → `Array<String>`, `Llm::Features.feature?(key)` → `Boolean`, `Llm::Features.grouped` → `Hash<String, Array<String>>`, `CustomExceptions::Llm::FeatureNotConfigured.new(feature: String)`.
- Consumes: `Llm::Config.bump_version!` (Task 2).

- [ ] **Step 1: Migration tạo bảng**

```ruby
class CreateLlmProvidersAndFeatureModels < ActiveRecord::Migration[7.2]
  def change
    create_table :llm_providers do |t|
      t.string :name, null: false
      t.string :provider_type, null: false
      t.text :api_key
      t.string :api_base

      t.timestamps
    end

    add_index :llm_providers, :name, unique: true
    add_index :llm_providers, :provider_type, unique: true

    create_table :llm_feature_models do |t|
      t.string :feature_key, null: false
      t.references :llm_provider, null: false, foreign_key: { on_delete: :restrict }
      t.string :model, null: false

      t.timestamps
    end

    add_index :llm_feature_models, :feature_key, unique: true
  end
end
```

- [ ] **Step 2: Thay toàn bộ `config/llm.yml`**

```yaml
features:
  reply_suggestion:
    group: editor
  summary:
    group: editor
  rewrite:
    group: editor
  follow_up:
    group: editor
  overview_summary:
    group: editor
  csat_analysis:
    group: editor
  copilot:
    group: copilot
  assistant:
    group: assistant
  false_promise_detection:
    group: assistant
  instruction_migration:
    group: assistant
  label_suggestion:
    group: conversation
  conversation_completion:
    group: conversation
  document_faq_generation:
    group: faq
  pdf_faq_generation:
    group: faq
  conversation_faq_generation:
    group: faq
  conversation_faq_matching:
    group: faq
  help_center_article_generation:
    group: help_center
  help_center_query_translation:
    group: help_center
  help_center_curation:
    group: help_center
  article_search_terms:
    group: help_center
  onboarding_content_generation:
    group: onboarding
  embedding:
    group: embedding
  audio_transcription:
    group: audio
```

- [ ] **Step 3: Tạo `lib/llm/features.rb`, xóa `lib/llm/models.rb`**

```ruby
module Llm::Features
  CONFIG = YAML.load_file(Rails.root.join('config/llm.yml')).fetch('features').freeze

  class << self
    def keys = CONFIG.keys
    def feature?(feature_key) = CONFIG.key?(feature_key.to_s)
    def grouped = keys.group_by { |feature_key| CONFIG.dig(feature_key, 'group') }
  end
end
```

```bash
git rm lib/llm/models.rb spec/lib/llm/models_spec.rb
```

- [ ] **Step 4: Tạo `app/models/llm_provider.rb`**

```ruby
class LlmProvider < ApplicationRecord
  PROVIDER_TYPES = %w[openai openrouter deepseek anthropic gemini mistral xai ollama].freeze

  encrypts :api_key

  has_many :llm_feature_models, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :provider_type, presence: true, uniqueness: true, inclusion: { in: PROVIDER_TYPES }
  validates :api_key, presence: true, unless: :ollama?
  validates :api_base, presence: true, if: :ollama?
  validate :api_base_supported

  after_commit -> { Llm::Config.bump_version! }

  def ollama?
    provider_type == 'ollama'
  end

  def masked_api_key
    "••••#{api_key.last(4)}" if api_key.present?
  end

  private

  def api_base_supported
    return if api_base.blank? || RubyLLM.config.respond_to?("#{provider_type}_api_base=")

    errors.add(:api_base, :invalid)
  end
end
```

- [ ] **Step 5: Tạo `app/models/llm_feature_model.rb`**

```ruby
class LlmFeatureModel < ApplicationRecord
  belongs_to :llm_provider

  before_validation { self.model = model.to_s.strip.presence }

  validates :feature_key, presence: true, uniqueness: true, inclusion: { in: ->(_record) { Llm::Features.keys } }
  validates :model, presence: true
end
```

- [ ] **Step 6: Tạo `lib/custom_exceptions/llm.rb`**

```ruby
module CustomExceptions::Llm
  class FeatureNotConfigured < CustomExceptions::Base
    def message
      I18n.t('errors.llm.feature_not_configured', feature: @data[:feature])
    end
  end
end
```

- [ ] **Step 7: Thêm i18n vào `config/locales/en.yml`** — ngay sau dòng `      invalid_api_key: 'OpenAI API key is invalid or revoked. Please check your key in your OpenAI dashboard.'` (khối `errors:` → `openai:`):

```yaml
    llm:
      feature_not_configured: 'The AI feature "%{feature}" has no model configured. Ask a Super Admin to configure it in Super Admin → Settings → Tekomi AI.'
```

- [ ] **Step 8: Chạy migration** (môi trường có Ruby)

```bash
bundle exec rails db:migrate
```
Expected: `db/schema.rb` có `llm_providers`, `llm_feature_models`.

---

### Task 2: FeatureRouter & Llm::Config

**Files:**
- Modify: `lib/llm/feature_router.rb` (thay toàn bộ)
- Modify: `lib/llm/config.rb` (thay toàn bộ)
- Modify: `enterprise/app/services/internal/account_analysis/content_evaluator_service.rb:5`

**Interfaces:**
- Consumes: `LlmFeatureModel`, `LlmProvider::PROVIDER_TYPES`, `Llm::Features.feature?`, `CustomExceptions::Llm::FeatureNotConfigured` (Task 1).
- Produces: `Llm::FeatureRouter.resolve(feature:)` → `{ feature: String, provider: Symbol, model: String }` (không còn tham số `account:`); `Llm::Config.apply!`; `Llm::Config.bump_version!`.

- [ ] **Step 1: Thay toàn bộ `lib/llm/feature_router.rb`**

```ruby
module Llm::FeatureRouter
  class UnknownFeatureError < StandardError; end

  class << self
    def resolve(feature:)
      feature_key = feature.to_s
      raise UnknownFeatureError, "Unknown LLM feature: #{feature_key}" unless Llm::Features.feature?(feature_key)

      feature_model = LlmFeatureModel.includes(:llm_provider).find_by(feature_key: feature_key)
      raise CustomExceptions::Llm::FeatureNotConfigured.new(feature: feature_key) if feature_model.blank?

      Llm::Config.apply!
      { feature: feature_key, provider: feature_model.llm_provider.provider_type.to_sym, model: feature_model.model }
    end
  end
end
```

- [ ] **Step 2: Thay toàn bộ `lib/llm/config.rb`**

```ruby
require 'ruby_llm'

module Llm::Config
  VERSION_KEY = 'LLM_PROVIDERS_CONFIG_VERSION'.freeze

  class << self
    def apply!
      version = $alfred.with { |conn| conn.get(VERSION_KEY) }.to_i
      return if @applied_version == version

      providers = LlmProvider.all.index_by(&:provider_type)
      RubyLLM.configure do |config|
        config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
        config.logger = Rails.logger
        LlmProvider::PROVIDER_TYPES.each { |provider_type| assign_provider(config, provider_type, providers[provider_type]) }
      end
      @applied_version = version
    end

    def bump_version!
      $alfred.with { |conn| conn.incr(VERSION_KEY) }
    end

    private

    def assign_provider(config, provider_type, provider)
      %w[api_key api_base].each do |attribute|
        setter = "#{provider_type}_#{attribute}="
        config.public_send(setter, provider&.public_send(attribute).presence) if config.respond_to?(setter)
      end
    end
  end
end
```

- [ ] **Step 3: `ContentEvaluatorService`** — thay `    Llm::Config.initialize!` bằng:

```ruby
    Llm::Config.apply!
```

---

### Task 3: Migration chuyển cấu hình cũ

**Files:**
- Create: `db/migrate/20260911000002_move_tekomi_llm_config_to_llm_providers.rb`

**Interfaces:**
- Consumes: bảng từ Task 1; `InstallationConfig`; `Chatwoot.encryption_configured?` (`config/application.rb:101`).

- [ ] **Step 1: Tạo migration**

```ruby
class MoveTekomiLlmConfigToLlmProviders < ActiveRecord::Migration[7.2]
  LEGACY_CONFIG_KEYS = %w[TEKOMI_OPEN_AI_API_KEY TEKOMI_OPEN_AI_MODEL TEKOMI_OPEN_AI_ENDPOINT TEKOMI_EMBEDDING_MODEL].freeze
  INSTALLATION_MODEL_FEATURES = %w[copilot assistant conversation_completion].freeze
  FEATURE_MODELS = {
    'reply_suggestion' => 'gpt-4.1-mini',
    'summary' => 'gpt-4.1-mini',
    'rewrite' => 'gpt-4.1-mini',
    'follow_up' => 'gpt-4.1-mini',
    'overview_summary' => 'gpt-4.1-mini',
    'csat_analysis' => 'gpt-4.1-mini',
    'copilot' => 'gpt-4.1',
    'assistant' => 'gpt-5.2',
    'false_promise_detection' => 'gpt-5.2',
    'instruction_migration' => 'gpt-5.2',
    'label_suggestion' => 'gpt-4.1-mini',
    'conversation_completion' => 'gpt-4.1',
    'document_faq_generation' => 'gpt-4.1-mini',
    'pdf_faq_generation' => 'gpt-4.1-mini',
    'conversation_faq_generation' => 'gpt-5.2',
    'conversation_faq_matching' => 'gpt-4.1-mini',
    'help_center_article_generation' => 'gpt-5.2',
    'help_center_query_translation' => 'gpt-4.1-nano',
    'help_center_curation' => 'gpt-4.1',
    'article_search_terms' => 'gpt-4o',
    'onboarding_content_generation' => 'gpt-4.1',
    'embedding' => 'text-embedding-3-small',
    'audio_transcription' => 'gpt-4o-mini-transcribe'
  }.freeze

  class MigrationLlmProvider < ApplicationRecord
    self.table_name = 'llm_providers'
    encrypts :api_key
  end

  class MigrationLlmFeatureModel < ApplicationRecord
    self.table_name = 'llm_feature_models'
  end

  def up
    api_key = legacy_value('TEKOMI_OPEN_AI_API_KEY')
    if api_key.present?
      raise 'ACTIVE_RECORD_ENCRYPTION_* must be configured before migrating the Tekomi AI API key' unless Chatwoot.encryption_configured?

      create_feature_models(create_provider(api_key))
    end

    InstallationConfig.where(name: LEGACY_CONFIG_KEYS).destroy_all
    execute("UPDATE accounts SET settings = settings - 'tekomi_models' WHERE settings ? 'tekomi_models'")
    execute("DELETE FROM integrations_hooks WHERE app_id = 'openai'")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def legacy_value(name)
    InstallationConfig.find_by(name: name)&.value.presence
  end

  def create_provider(api_key)
    endpoint = legacy_value('TEKOMI_OPEN_AI_ENDPOINT')
    host = endpoint && URI.parse(endpoint).host
    return MigrationLlmProvider.create!(name: 'OpenRouter', provider_type: 'openrouter', api_key: api_key) if host == 'openrouter.ai'
    return MigrationLlmProvider.create!(name: 'OpenAI', provider_type: 'openai', api_key: api_key) if host.blank? || host == 'api.openai.com'

    api_base = endpoint.chomp('/')
    api_base = "#{api_base}/v1" unless api_base.end_with?('/v1')
    MigrationLlmProvider.create!(name: 'OpenAI compatible', provider_type: 'openai', api_key: api_key, api_base: api_base)
  end

  def create_feature_models(provider)
    installation_model = legacy_value('TEKOMI_OPEN_AI_MODEL')
    embedding_model = legacy_value('TEKOMI_EMBEDDING_MODEL')

    FEATURE_MODELS.each do |feature_key, default_model|
      next if feature_key == 'audio_transcription' && provider.provider_type != 'openai'

      model = legacy_model(feature_key, default_model, installation_model, embedding_model)
      model = "openai/#{model}" if provider.provider_type == 'openrouter' && model.exclude?('/')
      MigrationLlmFeatureModel.create!(feature_key: feature_key, llm_provider_id: provider.id, model: model)
    end
  end

  def legacy_model(feature_key, default_model, installation_model, embedding_model)
    return embedding_model || default_model if feature_key == 'embedding'
    return installation_model || default_model if INSTALLATION_MODEL_FEATURES.include?(feature_key)

    default_model
  end
end
```

- [ ] **Step 2: Chạy migration** (sau khi backup DB)

```bash
bundle exec rails db:migrate
```
Expected: có 1 dòng `llm_providers` (nếu trước đó có key) và các dòng `llm_feature_models`; không còn `TEKOMI_OPEN_AI_*` trong `installation_configs`.

---

### Task 4: `Llm::BaseAiService` và các service con

**Files:**
- Modify: `enterprise/app/services/llm/base_ai_service.rb` (thay toàn bộ)
- Modify: `enterprise/app/services/tekomi/llm/contact_notes_service.rb:5`
- Modify: `enterprise/app/services/tekomi/llm/contact_attributes_service.rb:5`
- Modify: `enterprise/app/services/tekomi/llm/assistant_chat_service.rb:5`
- Modify: `enterprise/app/services/tekomi/llm/assistant_action_classifier_service.rb:6`
- Modify: `enterprise/app/services/tekomi/llm/faq_generator_service.rb:5`
- Modify: `enterprise/app/services/tekomi/copilot/chat_service.rb:8`
- Modify: `enterprise/app/services/tekomi/llm/conversation_faq_service.rb:22,85-87`
- Modify: `enterprise/app/services/tekomi/llm/assistant_false_promise_service.rb:2,8,40-42`

**Interfaces:**
- Consumes: `Llm::FeatureRouter.resolve(feature:)` (Task 2).
- Produces: `Llm::BaseAiService.new(feature:)`, `#model`, `#provider`, `#temperature`, `#chat(model: @model, provider: @provider, temperature: @temperature)`.

- [ ] **Step 1: Thay toàn bộ `enterprise/app/services/llm/base_ai_service.rb`**

```ruby
# frozen_string_literal: true

class Llm::BaseAiService
  DEFAULT_TEMPERATURE = 1.0

  attr_reader :model, :provider, :temperature

  def initialize(feature:)
    route = Llm::FeatureRouter.resolve(feature: feature)
    @model = route[:model]
    @provider = route[:provider]
    @temperature = DEFAULT_TEMPERATURE
  end

  def chat(model: @model, provider: @provider, temperature: @temperature)
    RubyLLM.chat(model: model, provider: provider, assume_model_exists: true).with_temperature(temperature)
  end

  private

  def sanitize_json_response(response)
    return response if response.nil?

    response.strip.sub(/\A```(?:\w*)\s*\n?/, '').sub(/\n?\s*```\s*\z/, '').strip
  end
end
```

- [ ] **Step 2: Bỏ `account:` trong `super(...)`**

| File | Dòng cũ | Dòng mới |
|---|---|---|
| `contact_notes_service.rb` | `    super(feature: 'assistant', account: conversation.account)` | `    super(feature: 'assistant')` |
| `contact_attributes_service.rb` | `    super(feature: 'assistant', account: conversation.account)` | `    super(feature: 'assistant')` |
| `assistant_chat_service.rb` | `    super(feature: 'assistant', account: assistant&.account \|\| conversation&.account)` | `    super(feature: 'assistant')` |
| `assistant_action_classifier_service.rb` | `    super(feature: 'assistant', account: conversation.account)` | `    super(feature: 'assistant')` |
| `faq_generator_service.rb` | `    super(feature: 'document_faq_generation', account: document.account)` | `    super(feature: 'document_faq_generation')` |
| `copilot/chat_service.rb` | `    super(feature: 'copilot', account: assistant.account)` | `    super(feature: 'copilot')` |

- [ ] **Step 3: `ConversationFaqService`**

Dòng 22 thay bằng:
```ruby
    super(feature: LLM_FEATURE)
```

Dòng 85–87 (`faq_match_model = ...` đến `chat(model: faq_match_model)`) thay bằng:
```ruby
    faq_match = Llm::FeatureRouter.resolve(feature: 'conversation_faq_matching')
    response = instrument_llm_call(match_instrumentation_params(prompt, comparison, faq_match[:model])) do
      chat(model: faq_match[:model], provider: faq_match[:provider])
```

- [ ] **Step 4: `AssistantFalsePromiseService`**

Xóa dòng `  DETECTOR_MODEL = 'gpt-5.2'.freeze` và dòng trống sau nó. Thay `    super()` bằng:
```ruby
    super(feature: 'false_promise_detection')
```
Xóa method:
```ruby
  def setup_model
    @model = DETECTOR_MODEL
  end

```

---

### Task 5: `Tekomi::BaseTaskService` và các service con

**Files:**
- Modify: `lib/tekomi/base_task_service.rb`
- Modify: `lib/llm/exception_trackable.rb` (thay toàn bộ)
- Modify: `lib/tekomi/reply_suggestion_service.rb:6,41-43`
- Modify: `lib/tekomi/summary_service.rb:6,28-30`
- Modify: `lib/tekomi/rewrite_service.rb:39,60-62`
- Modify: `lib/tekomi/follow_up_service.rb:36,107-109`
- Modify: `lib/tekomi/overview_summary_service.rb:9,75-77`
- Modify: `lib/tekomi/csat_utility_analysis_service.rb:6,67-69`
- Modify: `lib/tekomi/label_suggestion_service.rb:90-92`
- Modify: `enterprise/app/services/tekomi/assistant_overview_summary_service.rb:9,59-61`
- Modify: `enterprise/app/services/tekomi/assistant_migration/instruction_auditor.rb:2,7`
- Modify: `enterprise/app/services/tekomi/assistant_migration/instruction_classifier.rb:3,9`
- Modify: `enterprise/app/services/tekomi/llm/help_center_curation_service.rb:5-7,12`
- Modify: `enterprise/app/services/tekomi/llm/article_translation_service.rb:9,32-38`
- Modify: `enterprise/app/services/tekomi/llm/translate_query_service.rb:29-31`

**Interfaces:**
- Consumes: `Llm::FeatureRouter.resolve(feature:)` (Task 2), `CustomExceptions::Llm::FeatureNotConfigured` (Task 1).
- Produces: `make_api_call(messages:, feature:, schema: nil, tools: [])` (bỏ `model:`); `capture_llm_exception(error)`.

- [ ] **Step 1: `lib/tekomi/base_task_service.rb`**

Xóa dòng `  GPT_MODEL = Llm::Config::DEFAULT_MODEL`.

Xóa method `api_base` (dòng 34–38).

Thay các method `make_api_call`, `resolved_model`, `execute_ruby_llm_request`, `build_chat` (dòng 40–97) bằng:
```ruby
  def make_api_call(messages:, feature:, schema: nil, tools: [])
    return { error: I18n.t('tekomi.disabled'), error_code: 403 } unless tekomi_tasks_enabled?

    route = Llm::FeatureRouter.resolve(feature: feature)
    instrumentation_params = build_instrumentation_params(route[:model], messages)
    instrumentation_method = tools.any? ? :instrument_tool_session : :instrument_llm_call

    response = send(instrumentation_method, instrumentation_params) do
      execute_ruby_llm_request(route: route, messages: messages, schema: schema, tools: tools)
    end

    return response unless build_follow_up_context? && response[:message].present?

    response.merge(follow_up_context: build_follow_up_context(messages, response))
  rescue CustomExceptions::Llm::FeatureNotConfigured => e
    { error: e.message, error_code: 422 }
  end

  def execute_ruby_llm_request(route:, messages:, schema: nil, tools: [])
    chat = build_chat(route, messages: messages, schema: schema, tools: tools)

    conversation_messages = messages.reject { |m| m[:role] == 'system' }
    return { error: 'No conversation messages provided', error_code: 400, request_messages: messages } if conversation_messages.empty?

    add_messages_if_needed(chat, conversation_messages)
    build_ruby_llm_response(chat.ask(conversation_messages.last[:content]), messages)
  rescue StandardError => e
    capture_llm_exception(e)
    { error: e.message, request_messages: messages }
  end

  def build_chat(route, messages:, schema: nil, tools: [])
    chat = RubyLLM.chat(model: route[:model], provider: route[:provider], assume_model_exists: true)
    system_msg = messages.find { |m| m[:role] == 'system' }
    chat.with_instructions(system_msg[:content]) if system_msg
    chat.with_schema(schema) if schema

    if tools.any?
      tools.each { |tool| chat = chat.with_tool(tool) }
      chat.on_end_message { |message| record_generation(chat, message, route[:model]) }
    end

    chat
  end
```

Thay body `counts_toward_usage?` (`    llm_credential&.dig(:source) != :hook`) bằng:
```ruby
    true
```

Xóa các method: `api_key_configured?`, `api_key`, `llm_credential`, `use_account_openai_hook?`, `hook_llm_credential`, `system_llm_credential`, `openai_hook`, `system_api_key` (dòng 171–206).

- [ ] **Step 2: Thay toàn bộ `lib/llm/exception_trackable.rb`**

```ruby
module Llm::ExceptionTrackable
  private

  def capture_llm_exception(error)
    ChatwootExceptionTracker.new(error, account: exception_tracking_account).capture_exception
  end
end
```

- [ ] **Step 3: Tách feature Soạn thảo + bỏ override hook**

| File | Thay | Bằng |
|---|---|---|
| `reply_suggestion_service.rb` | `      feature: 'editor',` | `      feature: 'reply_suggestion',` |
| `summary_service.rb` | `      feature: 'editor',` | `      feature: 'summary',` |
| `rewrite_service.rb` | `      feature: 'editor',` | `      feature: 'rewrite',` |
| `follow_up_service.rb` | `    response = make_api_call(feature: 'editor', messages: messages)` | `    response = make_api_call(feature: 'follow_up', messages: messages)` |
| `overview_summary_service.rb` | `      feature: 'editor',` | `      feature: 'overview_summary',` |
| `csat_utility_analysis_service.rb` | `      feature: 'editor',` | `      feature: 'csat_analysis',` |
| `assistant_overview_summary_service.rb` | `    response = make_api_call(feature: 'editor', messages: messages, schema: RESPONSE_SCHEMA)` | `    response = make_api_call(feature: 'overview_summary', messages: messages, schema: RESPONSE_SCHEMA)` |

Trong 8 file sau, xóa khối (và dòng trống liền kề):
```ruby
  def use_account_openai_hook?
    true
  end
```
`reply_suggestion_service.rb`, `summary_service.rb`, `rewrite_service.rb`, `follow_up_service.rb`, `overview_summary_service.rb`, `csat_utility_analysis_service.rb`, `label_suggestion_service.rb`, `assistant_overview_summary_service.rb`.

- [ ] **Step 4: Bỏ model hardcode**

`instruction_auditor.rb`: xóa `  AUDITOR_MODEL = 'gpt-5.2'.freeze`; thay `      model: AUDITOR_MODEL,` bằng:
```ruby
      feature: 'instruction_migration',
```

`instruction_classifier.rb`: xóa `  CLASSIFIER_MODEL = 'gpt-5.2'.freeze`; thay dòng 9 bằng:
```ruby
    classifier_response = make_api_call(feature: 'instruction_migration', messages: messages, schema: RESPONSE_SCHEMA)
```

`help_center_curation_service.rb`: xóa 3 dòng
```ruby
  # This model consistently outperforms 5.2 in generating tighter and more
  # accurate curations.
  CURATION_MODEL = 'gpt-4.1'.freeze
```
và thay dòng `make_api_call` bằng:
```ruby
    response = make_api_call(feature: 'help_center_curation', messages: messages, schema: RESPONSE_SCHEMA)
```

`article_translation_service.rb`: thay dòng 9 bằng:
```ruby
    response = make_api_call(feature: 'help_center_article_generation', messages: messages)
```
và xóa 2 method:
```ruby
  def llm_credential
    @llm_credential ||= system_llm_credential
  end

  def translation_model
    @translation_model ||= InstallationConfig.find_by(name: 'TEKOMI_OPEN_AI_MODEL')&.value.presence || GPT_MODEL
  end

```

`translate_query_service.rb`, `article_writer_service.rb`, `widget_tagline_service.rb`, `help_center_curation_service.rb`, `enterprise/lib/tekomi/conversation_completion_service.rb`: xóa method (và comment ngay trên nếu có):
```ruby
  def llm_credential
    @llm_credential ||= system_llm_credential
  end

```

---

### Task 6: Embedding, chuyển giọng nói, từ khóa bài viết, bot V2

**Files:**
- Modify: `enterprise/app/services/tekomi/llm/embedding_service.rb` (thay toàn bộ)
- Modify: `enterprise/app/services/llm/speech_to_text_service.rb` (thay toàn bộ)
- Modify: `enterprise/app/models/enterprise/concerns/article.rb:65-88`
- Modify: `enterprise/app/models/concerns/agentable.rb`
- Modify: `enterprise/app/services/tekomi/assistant/response_rewriter.rb:66-74`
- Modify: `enterprise/app/services/tekomi/assistant/session_capture_service.rb:24,31`
- Delete: `config/initializers/ai_agents.rb`

**Interfaces:**
- Consumes: `Llm::FeatureRouter.resolve(feature:)` (Task 2).
- Produces: `Concerns::Agentable#agent_llm_route` → `{ feature:, provider:, model: }`.

- [ ] **Step 1: Thay toàn bộ `embedding_service.rb`**

```ruby
class Tekomi::Llm::EmbeddingService
  include Integrations::LlmInstrumentation

  class EmbeddingsError < StandardError; end

  def initialize(account_id: nil)
    @account_id = account_id
    @route = Llm::FeatureRouter.resolve(feature: 'embedding')
  end

  def get_embedding(content)
    return [] if content.blank?

    instrument_embedding_call(instrumentation_params(content)) do
      RubyLLM.embed(content, model: @route[:model], provider: @route[:provider], assume_model_exists: true).vectors
    end
  rescue RubyLLM::Error => e
    Rails.logger.error "Embedding API Error: #{e.message}"
    raise EmbeddingsError, "Failed to create an embedding: #{e.message}"
  end

  private

  def instrumentation_params(content)
    {
      span_name: 'llm.tekomi.embedding',
      model: @route[:model],
      input: content,
      feature_name: 'embedding',
      account_id: @account_id
    }
  end
end
```

- [ ] **Step 2: Thay toàn bộ `speech_to_text_service.rb`**

```ruby
# Blob-in, text-out audio transcription shared by voice-note attachments
# (Messages::AudioTranscriptionService) and voice-call recordings
# (Voice::CallTranscriptionService).
class Llm::SpeechToTextService
  include Integrations::LlmInstrumentation

  # OpenAI's transcription endpoint hard limit is 25 MB *decimal* (25_000_000), not
  # binary (25.megabytes = 26_214_400) — using the binary form leaks the 25.0–26.2 MB
  # range to the API as 413s. Long audio (~70+ min Opus) keeps the source audio but
  # skips transcription.
  BYTE_LIMIT = 25_000_000

  attr_reader :blob, :account, :route

  def self.available_for?(account)
    return false unless account.feature_enabled?('tekomi_integration')
    return false if account.audio_transcriptions.blank?

    account.usage_limits[:tekomi][:responses][:current_available].positive?
  end

  def self.too_large?(blob)
    blob.present? && blob.byte_size > BYTE_LIMIT
  end

  def initialize(blob:, account:)
    @blob = blob
    @account = account
    @route = Llm::FeatureRouter.resolve(feature: 'audio_transcription')
  end

  def perform
    temp_file_path = fetch_audio_file
    transcribed_text = instrument_audio_transcription(instrumentation_params(temp_file_path)) do
      # temperature: 0.0 minimises hallucinations on silence / near-silent
      # audio; non-zero values trigger spiraling repeats — well-documented
      # behaviour across OpenAI transcription models.
      RubyLLM.transcribe(temp_file_path, model: route[:model], provider: route[:provider], assume_model_exists: true, temperature: 0.0).text
    end

    account.increment_response_usage if transcribed_text.present?
    transcribed_text
  ensure
    FileUtils.rm_f(temp_file_path) if temp_file_path.present?
  end

  private

  def fetch_audio_file
    temp_dir = Rails.root.join('tmp/uploads/audio-transcriptions')
    FileUtils.mkdir_p(temp_dir)
    temp_file_name = "#{blob.key}-#{blob.filename}"

    if blob.filename.extension_without_delimiter.blank?
      extension = extension_from_content_type(blob.content_type)
      temp_file_name = "#{temp_file_name}.#{extension}" if extension.present?
    end

    temp_file_path = File.join(temp_dir, temp_file_name)

    File.open(temp_file_path, 'wb') do |file|
      blob.open do |blob_file|
        IO.copy_stream(blob_file, file)
      end
    end

    temp_file_path
  end

  def extension_from_content_type(content_type)
    subtype = content_type.to_s.downcase.split(';').first.to_s.split('/').last.to_s
    return if subtype.blank?

    {
      'x-m4a' => 'm4a',
      'x-wav' => 'wav',
      'x-mp3' => 'mp3'
    }.fetch(subtype, subtype)
  end

  def instrumentation_params(file_path)
    {
      span_name: 'llm.messages.audio_transcription',
      model: route[:model],
      account_id: account&.id,
      feature_name: 'audio_transcription',
      file_path: file_path
    }
  end
end
```

- [ ] **Step 3: `article.rb`** — thay từ `  def generate_article_search_terms` đến hết file bằng:

```ruby
  def generate_article_search_terms
    route = Llm::FeatureRouter.resolve(feature: 'article_search_terms')
    response = RubyLLM.chat(model: route[:model], provider: route[:provider], assume_model_exists: true)
                      .with_params(response_format: { type: 'json_object' })
                      .with_instructions(article_to_search_terms_prompt)
                      .ask("title: #{title} \n description: #{description} \n content: #{content}")
    JSON.parse(response.content)['search_terms']
  end
end
```

- [ ] **Step 4: `agentable.rb`**

Thay method `agent` (dòng 8–18) bằng:
```ruby
  def agent
    route = agent_llm_route
    Agents::Agent.new(
      name: agent_name,
      instructions: ->(context) { agent_instructions(context) },
      tools: agent_tools,
      model: route[:model],
      provider: route[:provider],
      assume_model_exists: true,
      temperature: temperature.presence&.to_f || DEFAULT_TEMPERATURE,
      response_schema: agent_response_schema,
      params: { max_tokens: DEFAULT_MAX_TOKENS }
    )
  end
```

Thay method `agent_model` (dòng 38–43) bằng:
```ruby
  def agent_llm_route
    Llm::FeatureRouter.resolve(feature: 'assistant')
  end
```

Xóa method private:
```ruby
  def installation_model
    InstallationConfig.find_by(name: 'TEKOMI_OPEN_AI_MODEL')&.value
  end

```

- [ ] **Step 5: `response_rewriter.rb`** — thay khối `agent = Agents::Agent.new(...)` trong `runner` bằng:

```ruby
      route = @assistant.agent_llm_route
      agent = Agents::Agent.new(
        name: AGENT_NAME,
        instructions: INSTRUCTIONS,
        model: route[:model],
        provider: route[:provider],
        assume_model_exists: true,
        temperature: 0,
        response_schema: Tekomi::ResponseSchema
      )
```

- [ ] **Step 6: `session_capture_service.rb`**

Thay `    model = @assistant.agent_model` bằng:
```ruby
    route = @assistant.agent_llm_route
```
Thay `      llm_model: "#{Llm::Models.provider_for(model)}-#{model}",` bằng:
```ruby
      llm_model: "#{route[:provider]}-#{route[:model]}",
```

- [ ] **Step 7: Xóa initializer**

```bash
git rm config/initializers/ai_agents.rb
```

---

### Task 7: Luồng PDF qua RubyLLM

**Files:**
- Modify: `enterprise/app/services/tekomi/llm/paginated_faq_generator_service.rb` (thay toàn bộ)
- Modify: `enterprise/app/jobs/tekomi/documents/crawl_job.rb:4-24`
- Modify: `enterprise/app/jobs/tekomi/documents/response_builder_job.rb` (`should_use_pagination?`)
- Modify: `enterprise/app/models/tekomi/document.rb:37,90-92`
- Modify: `lib/custom_exceptions/pdf.rb`
- Modify: `config/locales/en.yml` (`tekomi.documents`)
- Modify: `Gemfile:200`, `Gemfile.lock`
- Delete: `enterprise/app/services/tekomi/llm/pdf_processing_service.rb`, `enterprise/app/services/llm/legacy_base_open_ai_service.rb`, `spec/enterprise/services/tekomi/llm/pdf_processing_service_spec.rb`

**Interfaces:**
- Consumes: `Llm::BaseAiService.new(feature:)`, `#chat`, `#sanitize_json_response` (Task 4).

- [ ] **Step 1: Thay toàn bộ `paginated_faq_generator_service.rb`**

```ruby
class Tekomi::Llm::PaginatedFaqGeneratorService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  # Default pages per chunk - easily configurable
  DEFAULT_PAGES_PER_CHUNK = 10
  MAX_ITERATIONS = 20 # Safety limit to prevent infinite loops

  attr_reader :total_pages_processed, :iterations_completed

  def initialize(document, options = {})
    super(feature: 'pdf_faq_generation')
    @document = document
    @language = options[:language] || 'english'
    @pages_per_chunk = options[:pages_per_chunk] || DEFAULT_PAGES_PER_CHUNK
    @max_pages = options[:max_pages] # Optional limit from UI
    @total_pages_processed = 0
    @iterations_completed = 0
  end

  def generate
    @document.pdf_file.blob.open { |pdf_file| generate_paginated_faqs(pdf_file.path) }
  end

  # Method to check if we should continue processing
  def should_continue_processing?(last_chunk_result)
    # Stop if we've hit the maximum iterations
    return false if @iterations_completed >= MAX_ITERATIONS

    # Stop if we've processed the maximum pages specified
    return false if @max_pages && @total_pages_processed >= @max_pages

    # Stop if the last chunk returned no FAQs (likely no more content)
    return false if last_chunk_result[:faqs].empty?

    # Stop if the LLM explicitly indicates no more content
    return false if last_chunk_result[:has_content] == false

    # Continue processing
    true
  end

  private

  def generate_paginated_faqs(pdf_path)
    all_faqs = []
    current_page = 1

    loop do
      end_page = calculate_end_page(current_page)
      chunk_result = process_chunk_and_update_state(pdf_path, current_page, end_page, all_faqs)

      break unless should_continue_processing?(chunk_result)

      current_page = end_page + 1
    end

    deduplicate_faqs(all_faqs)
  end

  def calculate_end_page(current_page)
    end_page = current_page + @pages_per_chunk - 1
    @max_pages && end_page > @max_pages ? @max_pages : end_page
  end

  def process_chunk_and_update_state(pdf_path, current_page, end_page, all_faqs)
    chunk_result = process_page_chunk(pdf_path, current_page, end_page)
    chunk_faqs = chunk_result[:faqs]

    all_faqs.concat(chunk_faqs)
    @total_pages_processed = end_page
    @iterations_completed += 1

    chunk_result
  end

  def process_page_chunk(pdf_path, start_page, end_page)
    prompt = page_chunk_prompt(start_page, end_page)

    response = instrument_llm_call(build_instrumentation_params(prompt, start_page, end_page)) do
      chat.with_params(response_format: { type: 'json_object' }).ask(prompt, with: pdf_path)
    end

    result = parse_chunk_response(response.content)
    { faqs: result['faqs'] || [], has_content: result['has_content'] != false }
  rescue RubyLLM::Error => e
    Rails.logger.error I18n.t('tekomi.documents.page_processing_error', start: start_page, end: end_page, error: e.message)
    { faqs: [], has_content: false }
  end

  def page_chunk_prompt(start_page, end_page)
    Tekomi::Llm::SystemPromptsService.paginated_faq_generator(start_page, end_page, @language)
  end

  def parse_chunk_response(content)
    return { 'faqs' => [], 'has_content' => false } if content.nil?

    JSON.parse(sanitize_json_response(content))
  rescue JSON::ParserError => e
    Rails.logger.error "Error parsing chunk response: #{e.message}"
    { 'faqs' => [], 'has_content' => false }
  end

  def deduplicate_faqs(faqs)
    # Remove exact duplicates
    unique_faqs = faqs.uniq { |faq| faq['question'].downcase.strip }

    # Remove similar questions
    final_faqs = []
    unique_faqs.each do |faq|
      similar_exists = final_faqs.any? do |existing|
        similarity_score(existing['question'], faq['question']) > 0.85
      end

      final_faqs << faq unless similar_exists
    end

    Rails.logger.info "Deduplication: #{faqs.size} → #{final_faqs.size} FAQs"
    final_faqs
  end

  def similarity_score(str1, str2)
    words1 = str1.downcase.split(/\W+/).reject(&:empty?)
    words2 = str2.downcase.split(/\W+/).reject(&:empty?)
    common_words = words1 & words2
    total_words = (words1 + words2).uniq.size
    return 0 if total_words.zero?

    common_words.size.to_f / total_words
  end

  def build_instrumentation_params(prompt, start_page, end_page)
    {
      span_name: 'llm.paginated_faq_generation',
      account_id: @document&.account_id,
      feature_name: 'paginated_faq_generation',
      model: @model,
      messages: [{ role: 'user', content: prompt }],
      metadata: document_metadata.merge(start_page: start_page, end_page: end_page, iteration: @iterations_completed + 1)
    }
  end

  def document_metadata
    @document&.to_llm_metadata || {}
  end
end
```

- [ ] **Step 2: `crawl_job.rb`**

Thay:
```ruby
    if document.pdf_document?
      perform_pdf_processing(document)
```
bằng:
```ruby
    if document.pdf_document?
      document.update!(status: :available)
```
Xóa method `perform_pdf_processing` (dòng 18–24) và dòng trống liền kề.

- [ ] **Step 3: `response_builder_job.rb`** — thay body `should_use_pagination?` (chỉ PDF đã upload mới có file để gửi; link `.pdf` ngoài vẫn đi luồng FAQ thường như trước):

```ruby
  def should_use_pagination?(document)
    document.pdf_file.attached?
  end
```

- [ ] **Step 4: `document.rb`**

Thay dòng 37 bằng:
```ruby
  store_accessor :metadata, :content_fingerprint, :last_sync_error_code, :sync_step
```
Xóa:
```ruby
  def store_openai_file_id(file_id)
    update!(openai_file_id: file_id)
  end

```

- [ ] **Step 5: `lib/custom_exceptions/pdf.rb`** — xóa class `UploadError` và `FaqGenerationError`, giữ `ValidationError`:

```ruby
module CustomExceptions::Pdf
  class ValidationError < CustomExceptions::Base
    def initialize(message = 'PDF validation failed')
      super(message)
    end
  end
end
```

- [ ] **Step 6: `en.yml` → `tekomi.documents`** — xóa các dòng:
```yaml
      pdf_upload_failed: 'Failed to upload PDF to OpenAI'
      pdf_upload_success: 'PDF uploaded successfully with file_id: %{file_id}'
      pdf_processing_failed: 'Failed to process PDF document %{document_id}: %{error}'
      missing_openai_file_id: 'Document must have openai_file_id for paginated processing'
      openai_api_error: 'OpenAI API Error: %{error}'
```

- [ ] **Step 7: Xóa file và gem**

```bash
git rm enterprise/app/services/tekomi/llm/pdf_processing_service.rb enterprise/app/services/llm/legacy_base_open_ai_service.rb spec/enterprise/services/tekomi/llm/pdf_processing_service_spec.rb
```
Xóa dòng `gem 'ruby-openai'` trong `Gemfile`, rồi:
```bash
bundle install
```
Expected: `Gemfile.lock` không còn `ruby-openai`.

---

### Task 8: Xử lý lỗi Trợ thủ

**Files:**
- Modify: `enterprise/app/jobs/tekomi/copilot/response_job.rb:4-13`

**Interfaces:**
- Consumes: `CopilotMessage` (`message_type: :assistant`, `message: { content: }`), UI `CopilotAssistantMessage.vue` hiển thị `TEKOMI.COPILOT.EMPTY_MESSAGE` khi `content` rỗng; loader tắt khi tin cuối là `assistant`.

- [ ] **Step 1: Thay method `perform`**

```ruby
  def perform(assistant:, conversation_id:, user_id:, copilot_thread_id:, message:)
    Rails.logger.info("#{self.class.name} Copilot response job for assistant_id=#{assistant.id} user_id=#{user_id}")
    generate_chat_response(
      assistant: assistant,
      conversation_id: conversation_id,
      user_id: user_id,
      copilot_thread_id: copilot_thread_id,
      message: message
    )
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: assistant.account).capture_exception
    assistant.account.copilot_threads.find(copilot_thread_id).copilot_messages.create!(message: { content: '' }, message_type: :assistant)
  end
```

---

### Task 9: Giao diện Super Admin

**Files:**
- Modify: `config/routes.rb` (trong `namespace :super_admin`, sau `resource :settings, only: [:show]`)
- Create: `enterprise/app/controllers/super_admin/llm_providers_controller.rb`
- Create: `enterprise/app/controllers/super_admin/llm_feature_models_controller.rb`
- Create: `enterprise/app/views/super_admin/llm_providers/_tabs.html.erb`
- Create: `enterprise/app/views/super_admin/llm_providers/_form.html.erb`
- Create: `enterprise/app/views/super_admin/llm_providers/index.html.erb`
- Create: `enterprise/app/views/super_admin/llm_providers/new.html.erb`
- Create: `enterprise/app/views/super_admin/llm_providers/edit.html.erb`
- Create: `enterprise/app/views/super_admin/llm_feature_models/show.html.erb`
- Modify: `app/views/super_admin/application/_navigation.html.erb:36`
- Modify: `app/helpers/super_admin/features.yml` (khối `tekomi:`)
- Modify: `app/views/super_admin/settings/show.html.erb:41`
- Modify: `app/views/super_admin/application/_settings_menu.html.erb:13`
- Modify: `app/controllers/super_admin/app_configs_controller.rb:59`
- Modify: `enterprise/app/controllers/enterprise/super_admin/app_configs_controller.rb` (`tekomi_config_options`)
- Modify: `config/installation_config.yml:157-173`
- Modify: `app/models/installation_config.rb:18-29`
- Modify: `config/locales/en.yml` (`super_admin:`)

**Interfaces:**
- Consumes: `LlmProvider`, `LlmFeatureModel`, `Llm::Features.keys/grouped` (Task 1).
- Produces: routes `super_admin_llm_providers_path`, `new_super_admin_llm_provider_path`, `edit_super_admin_llm_provider_path(provider)`, `super_admin_llm_provider_path(provider)`, `super_admin_llm_feature_models_path`.

- [ ] **Step 1: Routes** — trong `namespace :super_admin`, ngay sau `      resource :settings, only: [:show]`:

```ruby

      if ChatwootApp.enterprise?
        resources :llm_providers, only: [:index, :new, :create, :edit, :update, :destroy]
        resource :llm_feature_models, only: [:show, :update]
      end
```

- [ ] **Step 2: `llm_providers_controller.rb`**

```ruby
class SuperAdmin::LlmProvidersController < SuperAdmin::EnterpriseBaseController
  before_action :set_llm_provider, only: [:edit, :update, :destroy]

  def index
    @llm_providers = LlmProvider.includes(:llm_feature_models).order(:name)
  end

  def new
    @llm_provider = LlmProvider.new
  end

  def edit; end

  def create
    @llm_provider = LlmProvider.new(llm_provider_params)
    return redirect_to super_admin_llm_providers_path, notice: I18n.t('super_admin.llm_providers.saved') if @llm_provider.save

    render :new, status: :unprocessable_entity
  end

  def update
    return redirect_to super_admin_llm_providers_path, notice: I18n.t('super_admin.llm_providers.saved') if @llm_provider.update(update_params)

    render :edit, status: :unprocessable_entity
  end

  def destroy
    return redirect_to super_admin_llm_providers_path, notice: I18n.t('super_admin.llm_providers.deleted') if @llm_provider.destroy

    redirect_to super_admin_llm_providers_path, alert: @llm_provider.errors.full_messages.join(', ')
  end

  private

  def set_llm_provider
    @llm_provider = LlmProvider.find(params[:id])
  end

  def llm_provider_params
    params.require(:llm_provider).permit(:name, :provider_type, :api_key, :api_base)
  end

  def update_params
    llm_provider_params.tap { |permitted| permitted.delete(:api_key) if permitted[:api_key].blank? }
  end
end
```

- [ ] **Step 3: `llm_feature_models_controller.rb`**

```ruby
class SuperAdmin::LlmFeatureModelsController < SuperAdmin::EnterpriseBaseController
  def show
    @llm_providers = LlmProvider.order(:name)
    @feature_models = LlmFeatureModel.all.index_by(&:feature_key)
  end

  def update
    ActiveRecord::Base.transaction do
      feature_params.each { |feature_key, attributes| save_feature_model(feature_key, attributes) }
    end
    redirect_to super_admin_llm_feature_models_path, notice: I18n.t('super_admin.llm_feature_models.saved')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to super_admin_llm_feature_models_path, alert: "#{e.record.feature_key}: #{e.record.errors.full_messages.join(', ')}"
  end

  private

  def feature_params
    params.require(:features).permit(Llm::Features.keys.index_with { %i[llm_provider_id model] })
  end

  def save_feature_model(feature_key, attributes)
    feature_model = LlmFeatureModel.find_or_initialize_by(feature_key: feature_key)
    return feature_model.destroy! if attributes[:llm_provider_id].blank? && attributes[:model].blank?

    feature_model.update!(llm_provider_id: attributes[:llm_provider_id], model: attributes[:model])
  end
end
```

- [ ] **Step 4: `_tabs.html.erb`**

```erb
<nav class="flex gap-6 px-8 border-b border-n-weak">
  <% [
       [t('super_admin.llm_config.tabs.features'), super_admin_llm_feature_models_path],
       [t('super_admin.llm_config.tabs.providers'), super_admin_llm_providers_path],
       [t('super_admin.llm_config.tabs.firecrawl'), super_admin_app_config_path(config: 'tekomi')]
     ].each do |label, path| %>
    <%= link_to label, path, class: "py-3 text-sm #{current_page?(path) ? 'text-woot-500 border-b-2 border-woot-500' : 'text-slate-800 hover:text-woot-500'}" %>
  <% end %>
</nav>
```

- [ ] **Step 5: `_form.html.erb`**

```erb
<%= form_with model: @llm_provider, scope: :llm_provider, url: form_url do |form| %>
  <% if @llm_provider.errors.any? %>
    <p class="mb-6 text-sm text-red-600"><%= @llm_provider.errors.full_messages.join(', ') %></p>
  <% end %>
  <div class="flex mb-8">
    <div class="field-unit__label"><%= form.label :name, t('super_admin.llm_providers.fields.name') %></div>
    <div class="-mt-2 field-unit__field"><%= form.text_field :name %></div>
  </div>
  <div class="flex mb-8">
    <div class="field-unit__label"><%= form.label :provider_type, t('super_admin.llm_providers.fields.provider_type') %></div>
    <div class="-mt-2 field-unit__field">
      <%= form.select :provider_type,
                      LlmProvider::PROVIDER_TYPES.map { |type| [t("super_admin.llm_providers.types.#{type}"), type] },
                      {},
                      class: 'mt-2 border border-slate-100 p-1 rounded-md' %>
    </div>
  </div>
  <div class="flex mb-8">
    <div class="field-unit__label"><%= form.label :api_key, t('super_admin.llm_providers.fields.api_key') %></div>
    <div class="-mt-2 field-unit__field">
      <%= form.password_field :api_key, value: nil, autocomplete: 'new-password', class: 'mt-2 border border-slate-100 p-1.5 rounded-md w-full' %>
      <% if @llm_provider.persisted? %>
        <p class="pt-2 text-xs italic text-slate-400"><%= t('super_admin.llm_providers.api_key_keep_hint') %></p>
      <% end %>
    </div>
  </div>
  <div class="flex mb-8">
    <div class="field-unit__label"><%= form.label :api_base, t('super_admin.llm_providers.fields.api_base') %></div>
    <div class="-mt-2 field-unit__field">
      <%= form.text_field :api_base %>
      <p class="pt-2 text-xs italic text-slate-400"><%= t('super_admin.llm_providers.api_base_hint') %></p>
    </div>
  </div>
  <div class="form-actions"><%= form.submit t('super_admin.llm_providers.save') %></div>
<% end %>
```

- [ ] **Step 6: `index.html.erb`**

```erb
<% content_for(:title) { t('super_admin.llm_config.title') } %>
<header class="main-content__header" role="banner">
  <h1 class="main-content__page-title" id="page-title"><%= content_for(:title) %></h1>
  <%= link_to t('super_admin.llm_providers.new'), new_super_admin_llm_provider_path, class: 'button' %>
</header>
<%= render 'super_admin/llm_providers/tabs' %>
<section class="main-content__body">
  <table>
    <thead>
      <tr>
        <th><%= t('super_admin.llm_providers.fields.name') %></th>
        <th><%= t('super_admin.llm_providers.fields.provider_type') %></th>
        <th><%= t('super_admin.llm_providers.fields.api_base') %></th>
        <th><%= t('super_admin.llm_providers.fields.api_key') %></th>
        <th><%= t('super_admin.llm_providers.fields.usage') %></th>
        <th></th>
      </tr>
    </thead>
    <tbody>
      <% @llm_providers.each do |provider| %>
        <tr>
          <td><%= provider.name %></td>
          <td><%= t("super_admin.llm_providers.types.#{provider.provider_type}") %></td>
          <td><%= provider.api_base.presence || t('super_admin.llm_providers.default_api_base') %></td>
          <td><%= provider.masked_api_key %></td>
          <td><%= t('super_admin.llm_providers.usage', count: provider.llm_feature_models.size) %></td>
          <td>
            <div class="flex items-center gap-3">
              <%= link_to t('super_admin.llm_providers.edit'), edit_super_admin_llm_provider_path(provider) %>
              <% if provider.llm_feature_models.empty? %>
                <%= button_to t('super_admin.llm_providers.delete'), super_admin_llm_provider_path(provider), method: :delete %>
              <% end %>
            </div>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
</section>
```

- [ ] **Step 7: `new.html.erb` và `edit.html.erb`**

`new.html.erb`:
```erb
<% content_for(:title) { t('super_admin.llm_config.title') } %>
<header class="main-content__header" role="banner">
  <h1 class="main-content__page-title" id="page-title"><%= t('super_admin.llm_providers.new') %></h1>
</header>
<%= render 'super_admin/llm_providers/tabs' %>
<section class="main-content__body">
  <%= render 'super_admin/llm_providers/form', form_url: super_admin_llm_providers_path %>
</section>
```

`edit.html.erb`:
```erb
<% content_for(:title) { t('super_admin.llm_config.title') } %>
<header class="main-content__header" role="banner">
  <h1 class="main-content__page-title" id="page-title"><%= @llm_provider.name %></h1>
</header>
<%= render 'super_admin/llm_providers/tabs' %>
<section class="main-content__body">
  <%= render 'super_admin/llm_providers/form', form_url: super_admin_llm_provider_path(@llm_provider) %>
</section>
```

- [ ] **Step 8: `llm_feature_models/show.html.erb`**

```erb
<% content_for(:title) { t('super_admin.llm_config.title') } %>
<header class="main-content__header" role="banner">
  <h1 class="main-content__page-title" id="page-title"><%= content_for(:title) %></h1>
</header>
<%= render 'super_admin/llm_providers/tabs' %>
<section class="main-content__body">
  <% unconfigured_count = Llm::Features.keys.count { |feature_key| @feature_models[feature_key].blank? } %>
  <% if unconfigured_count.positive? %>
    <p class="mb-4 text-sm text-amber-700"><%= t('super_admin.llm_feature_models.unconfigured_summary', count: unconfigured_count) %></p>
  <% end %>
  <%= form_with url: super_admin_llm_feature_models_path, method: :patch do |form| %>
    <% Llm::Features.grouped.each do |group, feature_keys| %>
      <h2 class="mt-8 mb-2 text-base font-medium text-n-slate-12"><%= t("super_admin.llm_feature_models.groups.#{group}") %></h2>
      <table>
        <tbody>
          <% feature_keys.each do |feature_key| %>
            <% feature_model = @feature_models[feature_key] %>
            <% warning = t("super_admin.llm_feature_models.features.#{feature_key}.warning", default: '') %>
            <tr>
              <td class="w-2/5">
                <div class="text-sm font-medium text-n-slate-12"><%= t("super_admin.llm_feature_models.features.#{feature_key}.name") %></div>
                <div class="text-xs text-slate-500"><%= t("super_admin.llm_feature_models.features.#{feature_key}.description") %></div>
                <% if warning.present? %>
                  <div class="mt-1 text-xs text-amber-700"><%= warning %></div>
                <% end %>
              </td>
              <td>
                <%= form.select "features[#{feature_key}][llm_provider_id]",
                                options_from_collection_for_select(@llm_providers, :id, :name, feature_model&.llm_provider_id),
                                { include_blank: t('super_admin.llm_feature_models.select_provider') },
                                class: 'border border-slate-100 p-1 rounded-md' %>
              </td>
              <td><%= form.text_field "features[#{feature_key}][model]", value: feature_model&.model %></td>
              <td class="text-xs <%= feature_model ? 'text-green-700' : 'text-amber-700' %>">
                <%= feature_model ? t('super_admin.llm_feature_models.configured') : t('super_admin.llm_feature_models.not_configured') %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% end %>
    <div class="form-actions"><%= form.submit t('super_admin.llm_feature_models.save') %></div>
  <% end %>
</section>
```

- [ ] **Step 9: Ẩn 2 resource khỏi sidebar Administrate** — `_navigation.html.erb:36`, thêm `"llm_providers", "llm_feature_models"` vào mảng:

```erb
        <% next if ["account_users", "access_tokens", "installation_configs", "dashboard", "devise/sessions", "app_configs", "instance_statuses", "settings", "push_diagnostics", "llm_providers", "llm_feature_models"].include?  resource.resource %>
```

- [ ] **Step 10: Thẻ Tekomi AI trỏ sang trang mới**

`app/helpers/super_admin/features.yml`, khối `tekomi:` thêm dòng sau `  config_key: 'tekomi'`:
```yaml
  config_url: '/super_admin/llm_feature_models'
```

`app/views/super_admin/settings/show.html.erb:41` thay `href="/super_admin/app_config?config=<%= attrs[:config_key] %>"` bằng:
```erb
href="<%= attrs[:config_url] || "/super_admin/app_config?config=#{attrs[:config_key]}" %>"
```

`app/views/super_admin/application/_settings_menu.html.erb:13` thay bằng:
```erb
        <% url = attrs['config_url'] || super_admin_app_config_url(config: attrs['config_key']) %>
```

- [ ] **Step 11: Form app_config `tekomi` chỉ còn FireCrawl**

`app/controllers/super_admin/app_configs_controller.rb`: xóa dòng `      'tekomi' => %w[TEKOMI_OPEN_AI_API_KEY TEKOMI_OPEN_AI_MODEL TEKOMI_OPEN_AI_ENDPOINT]` và xóa dấu phẩy cuối dòng `'google' => ...` phía trên.

`enterprise/app/controllers/enterprise/super_admin/app_configs_controller.rb`: thay `tekomi_config_options` bằng:
```ruby
  def tekomi_config_options
    %w[TEKOMI_FIRECRAWL_API_KEY]
  end
```

`config/installation_config.yml`: xóa 4 mục `TEKOMI_OPEN_AI_API_KEY`, `TEKOMI_OPEN_AI_MODEL`, `TEKOMI_OPEN_AI_ENDPOINT`, `TEKOMI_EMBEDDING_MODEL` (dòng 157–173).

`app/models/installation_config.rb`: thay dòng 18–29 bằng:
```ruby
  RESTART_REQUIRED_CONFIG_KEYS = %w[
    LANGFUSE_BASE_URL
    LANGFUSE_PUBLIC_KEY
    LANGFUSE_SECRET_KEY
    OTEL_PROVIDER
  ].freeze
```

- [ ] **Step 12: i18n `super_admin:` trong `en.yml`** — thay toàn bộ khối `    tekomi_model_overrides:` (dòng 644–672) bằng:

```yaml
    llm_config:
      title: 'Tekomi AI'
      tabs:
        features: 'AI features'
        providers: 'Providers'
        firecrawl: 'FireCrawl'
    llm_providers:
      new: 'Add provider'
      edit: 'Edit'
      delete: 'Delete'
      save: 'Save provider'
      saved: 'Provider saved.'
      deleted: 'Provider deleted.'
      default_api_base: 'Provider default'
      api_key_keep_hint: 'Leave blank to keep the current API key.'
      api_base_hint: 'Optional. Enter the full base URL including the version path, for example https://openrouter.ai/api/v1. Required for Ollama. Not supported for Mistral and xAI.'
      usage:
        zero: 'Not used'
        one: 'Used by 1 feature'
        other: 'Used by %{count} features'
      fields:
        name: 'Name'
        provider_type: 'Type'
        api_key: 'API key'
        api_base: 'Endpoint'
        usage: 'Usage'
      types:
        openai: 'OpenAI / OpenAI-compatible'
        openrouter: 'OpenRouter'
        deepseek: 'DeepSeek'
        anthropic: 'Anthropic'
        gemini: 'Gemini'
        mistral: 'Mistral'
        xai: 'xAI'
        ollama: 'Ollama'
    llm_feature_models:
      save: 'Save'
      saved: 'AI feature models saved.'
      select_provider: 'Select provider'
      configured: 'Configured'
      not_configured: 'Not configured'
      unconfigured_summary:
        one: '1 AI feature is not configured.'
        other: '%{count} AI features are not configured.'
      groups:
        editor: 'Editor'
        copilot: 'Copilot'
        assistant: 'Assistant'
        conversation: 'Conversations'
        faq: 'FAQ'
        help_center: 'Help Center'
        onboarding: 'Onboarding'
        embedding: 'Embeddings'
        audio: 'Audio'
      features:
        reply_suggestion:
          name: 'Reply suggestion'
          description: 'Drafts a reply for the agent in the message editor.'
        summary:
          name: 'Conversation summary'
          description: 'Summarizes the open conversation.'
        rewrite:
          name: 'Rewrite'
          description: 'Improves, changes the tone of, or fixes grammar in the editor text.'
        follow_up:
          name: 'Follow-up'
          description: 'Refines a previous AI result from the agent follow-up instruction.'
        overview_summary:
          name: 'Overview summary'
          description: 'Generates conversation and assistant overview summaries.'
        csat_analysis:
          name: 'CSAT analysis'
          description: 'Analyzes CSAT responses.'
        copilot:
          name: 'Copilot'
          description: 'Answers agent questions in the Copilot panel.'
        assistant:
          name: 'Assistant replies'
          description: 'Replies to customers, writes contact notes and attributes, and classifies assistant actions.'
        false_promise_detection:
          name: 'False promise detection'
          description: 'Checks assistant replies for promises the assistant cannot keep.'
        instruction_migration:
          name: 'Instruction migration'
          description: 'Classifies and audits assistant instructions when migrating to the new assistant.'
        label_suggestion:
          name: 'Label suggestion'
          description: 'Suggests labels for conversations.'
        conversation_completion:
          name: 'Conversation completion'
          description: 'Decides whether an inactive conversation can be resolved.'
        document_faq_generation:
          name: 'Document FAQ generation'
          description: 'Creates FAQs from crawled documents.'
        pdf_faq_generation:
          name: 'PDF FAQ generation'
          description: 'Creates FAQs from uploaded PDFs.'
          warning: 'The whole PDF is sent with every page batch. Prefer a model that reads PDFs natively (for example openai/gpt-4.1-mini); on OpenRouter other models are billed for OCR on every request.'
        conversation_faq_generation:
          name: 'Conversation FAQ generation'
          description: 'Creates FAQ suggestions from conversations.'
        conversation_faq_matching:
          name: 'Conversation FAQ matching'
          description: 'Checks whether a suggested FAQ duplicates an existing one.'
        help_center_article_generation:
          name: 'Help Center article writing'
          description: 'Writes and translates Help Center articles.'
        help_center_query_translation:
          name: 'Help Center search translation'
          description: 'Translates Help Center search queries.'
        help_center_curation:
          name: 'Help Center curation'
          description: 'Selects categories and articles from website links during onboarding.'
        article_search_terms:
          name: 'Article search terms'
          description: 'Generates search terms used to index Help Center articles.'
        onboarding_content_generation:
          name: 'Onboarding content'
          description: 'Analyzes the website and writes the widget tagline during onboarding.'
        embedding:
          name: 'Embeddings'
          description: 'Creates vectors for document, FAQ and article search.'
          warning: 'The model must return 1536-dimension vectors. Switching to a model with a different size requires a migration and regenerating all embeddings.'
        audio_transcription:
          name: 'Audio transcription'
          description: 'Transcribes voice messages and call recordings.'
          warning: 'The provider must support an OpenAI-style transcription API, for example OpenAI, Gemini or OpenRouter.'
```

---

### Task 10: Bỏ chọn model theo account

**Files:**
- Modify: `app/models/account.rb:58`
- Modify: `app/models/concerns/tekomi_featurable.rb` (thay toàn bộ)
- Modify: `app/models/concerns/account_settings_schema.rb:4-5,23-27`
- Modify: `app/dashboards/account_dashboard.rb:21,62,86,125`
- Modify: `app/controllers/super_admin/accounts_controller.rb:42`
- Delete: `enterprise/app/fields/tekomi_model_overrides_field.rb`, `enterprise/app/views/fields/tekomi_model_overrides_field/`
- Modify: `app/controllers/api/v1/accounts/tekomi/preferences_controller.rb` (thay toàn bộ)
- Modify: `app/javascript/dashboard/routes/dashboard/settings/tekomi/Index.vue`
- Modify: `app/javascript/dashboard/routes/dashboard/settings/tekomi/components/FeatureToggle.vue` (thay toàn bộ)
- Delete: `app/javascript/dashboard/routes/dashboard/settings/tekomi/components/ModelSelector.vue`, `ModelDropdown.vue`
- Modify: `app/javascript/dashboard/store/tekomi/preferences.js` (thay toàn bộ)
- Modify: `app/javascript/dashboard/i18n/locale/en/settings.json:535-576`

**Interfaces:**
- Produces: `TekomiFeaturable::TOGGLE_FEATURE_KEYS = %w[label_suggestion help_center_search audio_transcription]`; API `GET/PATCH /api/v1/accounts/:id/tekomi/preferences` → `{ features: { <key>: { enabled: Boolean } } }`; store `useTekomiConfigStore` với `features`, `uiFlags`, `fetch()`, `updatePreferences(data)`.

- [ ] **Step 1: `account.rb:58`**

```ruby
  store_accessor :settings, :tekomi_features
```

- [ ] **Step 2: Thay toàn bộ `tekomi_featurable.rb`**

```ruby
# frozen_string_literal: true

module TekomiFeaturable
  extend ActiveSupport::Concern

  TOGGLE_FEATURE_KEYS = %w[label_suggestion help_center_search audio_transcription].freeze

  def tekomi_preferences
    stored_features = tekomi_features || {}
    { features: TOGGLE_FEATURE_KEYS.index_with { |feature_key| stored_features[feature_key] == true } }.with_indifferent_access
  end
end
```

- [ ] **Step 3: `account_settings_schema.rb`**

Thay dòng 4–5 bằng:
```ruby
  TEKOMI_FEATURE_PROPERTIES = TekomiFeaturable::TOGGLE_FEATURE_KEYS.index_with { { 'type': %w[boolean null] } }.freeze
```
Xóa khối:
```ruby
        'tekomi_models': {
          'type': %w[object null],
          'properties': TEKOMI_MODEL_PROPERTIES,
          'additionalProperties': false
        },
```

- [ ] **Step 4: `account_dashboard.rb`** — xóa 3 dòng `attributes[:tekomi_models] = TekomiModelOverridesField`, `attrs << :tekomi_models` (2 chỗ) và thay dòng 125 bằng:

```ruby
    attrs = super + [limits: {}]
```

- [ ] **Step 5: `super_admin/accounts_controller.rb`** — xóa dòng:

```ruby
    permitted_params[:tekomi_models] = permitted_params[:tekomi_models].to_h.compact_blank.presence if permitted_params.key?(:tekomi_models)
```

- [ ] **Step 6: Xóa field Administrate**

```bash
git rm -r enterprise/app/fields/tekomi_model_overrides_field.rb enterprise/app/views/fields/tekomi_model_overrides_field
```

- [ ] **Step 7: Thay toàn bộ `preferences_controller.rb`**

```ruby
class Api::V1::Accounts::Tekomi::PreferencesController < Api::V1::Accounts::BaseController
  before_action :authorize_account_update, only: [:update]

  def show
    render json: preferences_payload
  end

  def update
    @current_account.tekomi_features = (@current_account.tekomi_features || {}).merge(permitted_tekomi_features)
    @current_account.save!

    render json: preferences_payload
  end

  private

  def authorize_account_update
    authorize @current_account, :update?
  end

  def permitted_tekomi_features
    params.require(:tekomi_features).permit(*TekomiFeaturable::TOGGLE_FEATURE_KEYS).to_h.stringify_keys
  end

  def preferences_payload
    { features: @current_account.tekomi_preferences[:features].transform_values { |enabled| { enabled: enabled } } }
  end
end
```

- [ ] **Step 8: `Index.vue`**

Xóa dòng `import ModelSelector from './components/ModelSelector.vue';`.
Xóa `const modelFeatures = computed(() => [ ... ]);` (dòng 28–46).
Xóa function `handleModelChange` (dòng 102–112).
Trong template, xóa khối:
```vue
        <!-- Model Configuration Section -->
        <SectionLayout
          :title="t('TEKOMI_SETTINGS.MODEL_CONFIG.TITLE')"
          :description="t('TEKOMI_SETTINGS.MODEL_CONFIG.DESCRIPTION')"
        >
          <div class="grid gap-4">
            <ModelSelector
              v-for="feature in modelFeatures"
              v-show="shouldShowFeature(feature)"
              :key="feature.key"
              :is-allowed="isFeatureAccessible(feature)"
              :feature-key="feature.key"
              :title="feature.title"
              :description="feature.description"
              @change="handleModelChange"
            />
          </div>
        </SectionLayout>

```
Trong khối Features: xóa prop `with-border` và dòng `@model-change="handleModelChange"`.

- [ ] **Step 9: Thay toàn bộ `FeatureToggle.vue`**

```vue
<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useTekomiConfigStore } from 'dashboard/store/tekomi/preferences';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  featureKey: {
    type: String,
    required: true,
  },
  isAllowed: {
    type: Boolean,
    required: true,
  },
});

const emit = defineEmits(['change']);

const { t } = useI18n();
const tekomiConfigStore = useTekomiConfigStore();
const { features } = storeToRefs(tekomiConfigStore);

const isEnabled = ref(false);

const featureConfig = computed(() => features.value[props.featureKey]);

const title = computed(() => {
  if (props.featureKey.toUpperCase() === 'AUDIO_TRANSCRIPTION') {
    return t('TEKOMI_SETTINGS.FEATURES.AUDIO_TRANSCRIPTION.TITLE');
  }
  if (props.featureKey.toUpperCase() === 'HELP_CENTER_SEARCH') {
    return t('TEKOMI_SETTINGS.FEATURES.HELP_CENTER_SEARCH.TITLE');
  }
  if (props.featureKey.toUpperCase() === 'LABEL_SUGGESTION') {
    return t('TEKOMI_SETTINGS.FEATURES.LABEL_SUGGESTION.TITLE');
  }
  return '';
});

const description = computed(() => {
  if (props.featureKey.toUpperCase() === 'AUDIO_TRANSCRIPTION') {
    return t('TEKOMI_SETTINGS.FEATURES.AUDIO_TRANSCRIPTION.DESCRIPTION');
  }
  if (props.featureKey.toUpperCase() === 'HELP_CENTER_SEARCH') {
    return t('TEKOMI_SETTINGS.FEATURES.HELP_CENTER_SEARCH.DESCRIPTION');
  }
  if (props.featureKey.toUpperCase() === 'LABEL_SUGGESTION') {
    return t('TEKOMI_SETTINGS.FEATURES.LABEL_SUGGESTION.DESCRIPTION');
  }
  return '';
});

watch(
  featureConfig,
  newConfig => {
    if (newConfig !== undefined) {
      isEnabled.value = !!newConfig.enabled;
    }
  },
  { immediate: true }
);

const toggleFeature = () => {
  emit('change', { feature: props.featureKey, enabled: isEnabled.value });
};
</script>

<template>
  <div
    class="p-4 rounded-xl border border-n-weak bg-n-solid-1 flex items-center justify-between gap-4"
    :class="{ 'opacity-60 pointer-events-none': !isAllowed }"
  >
    <div class="flex-1 min-w-0">
      <h4 class="text-sm font-medium text-n-slate-12">{{ title }}</h4>
      <p class="text-sm text-n-slate-11 mt-0.5">{{ description }}</p>
    </div>
    <div v-if="isAllowed" class="flex-shrink-0">
      <Switch v-model="isEnabled" @change="toggleFeature" />
    </div>
  </div>
</template>
```

- [ ] **Step 10: Xóa component chọn model**

```bash
git rm app/javascript/dashboard/routes/dashboard/settings/tekomi/components/ModelSelector.vue app/javascript/dashboard/routes/dashboard/settings/tekomi/components/ModelDropdown.vue
```

- [ ] **Step 11: Thay toàn bộ `store/tekomi/preferences.js`**

```js
import { defineStore } from 'pinia';
import TekomiPreferencesAPI from 'dashboard/api/tekomi/preferences';

export const useTekomiConfigStore = defineStore('tekomiConfig', {
  state: () => ({
    features: {},
    uiFlags: {
      isFetching: false,
    },
  }),

  getters: {
    getFeatures: state => state.features,
    getUIFlags: state => state.uiFlags,
  },

  actions: {
    async fetch() {
      this.uiFlags.isFetching = true;
      try {
        const response = await TekomiPreferencesAPI.get();
        this.features = response.data.features || {};
      } catch (error) {
        // Ignore error
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    async updatePreferences(data) {
      const response = await TekomiPreferencesAPI.updatePreferences(data);
      this.features = response.data.features || {};
    },
  },
});
```

- [ ] **Step 12: `settings.json` → `TEKOMI_SETTINGS`**

Thay `"DESCRIPTION"` dòng 535 bằng:
```json
    "DESCRIPTION": "Enable or disable Tekomi AI features for your account. Tekomi AI follows a credit based billing, you will be charged credits for every action Tekomi AI takes.",
```
Xóa toàn bộ khối `"MODEL_CONFIG": { ... },` (dòng 539–557).
Trong `AUDIO_TRANSCRIPTION` và `LABEL_SUGGESTION`: xóa dòng `"MODEL_TITLE"` và `"MODEL_DESCRIPTION"`, bỏ dấu phẩy cuối dòng `"DESCRIPTION"` phía trên.

---

### Task 11: Bỏ Integration OpenAI

**Files:**
- Modify: `config/integration/apps.yml:26-59`
- Modify: `app/models/integrations/hook.rb`
- Delete: `lib/integrations/openai/key_validator.rb`, `app/jobs/migration/validate_openai_hooks_job.rb`, `lib/integrations/llm_base_service.rb`
- Delete specs: `spec/lib/integrations/openai/key_validator_spec.rb`, `spec/jobs/migration/validate_openai_hooks_job_spec.rb`, `spec/lib/integrations/llm_base_service_spec.rb`
- Modify: `app/javascript/dashboard/routes/dashboard/settings/integrations/NewHook.vue:67-69`
- Modify: `app/javascript/dashboard/i18n/locale/en/integrationApps.json:49`
- Modify: `app/javascript/dashboard/composables/useLabelSuggestions.js` (thay toàn bộ)
- Modify: `config/locales/en.yml` (`errors.openai`, `integration_apps.openai`)

**Interfaces:**
- Consumes: `useTekomiConfigStore().features.label_suggestion.enabled` (Task 10).

- [ ] **Step 1: `apps.yml`** — xóa toàn bộ khối từ dòng `openai:` đến dòng ngay trước `linear:`.

- [ ] **Step 2: `hook.rb`**

Xóa dòng `  validate :validate_openai_api_key, if: :validate_openai_api_key?`.
Xóa các method:
```ruby
  def openai?
    app_id == 'openai'
  end

```
```ruby
  # TODO: When adding credential validation for other integrations (dialogflow, dyte, etc.),
  # extract this into an app-level config flag in apps.yml instead of hardcoding app_id checks.
  def validate_openai_api_key?
    openai? && enabled? && (new_record? || openai_api_key_changed? || will_save_change_to_status?)
  end

```
```ruby
  def openai_api_key_changed?
    settings_api_key(settings) != settings_api_key(settings_in_database)
  end

```
```ruby
  def validate_openai_api_key
    return if Integrations::Openai::KeyValidator.valid?(settings_api_key(settings))

    errors.add(:base, I18n.t('errors.openai.invalid_api_key'))
  end

```
```ruby
  def settings_api_key(value)
    settings_value(value, 'api_key')
  end

```
Thay comment trong `process_event` `    # OpenAI integration migrated to Tekomi::EditorService` bằng không có dòng đó (xóa dòng).

- [ ] **Step 3: Xóa file**

```bash
git rm lib/integrations/openai/key_validator.rb app/jobs/migration/validate_openai_hooks_job.rb lib/integrations/llm_base_service.rb spec/lib/integrations/openai/key_validator_spec.rb spec/jobs/migration/validate_openai_hooks_job_spec.rb spec/lib/integrations/llm_base_service_spec.rb
```

- [ ] **Step 4: `NewHook.vue`** — xóa:

```js
      if (this.integration.id === 'openai' && this.uiFlags.isCreatingHook) {
        return this.$t('INTEGRATION_APPS.ADD.FORM.VALIDATING_OPENAI');
      }

```

- [ ] **Step 5: `integrationApps.json`** — xóa dòng:

```json
        "VALIDATING_OPENAI": "Validating with OpenAI...",
```

- [ ] **Step 6: Thay toàn bộ `useLabelSuggestions.js`**

```js
import { computed, onMounted } from 'vue';
import { storeToRefs } from 'pinia';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useTekomiConfigStore } from 'dashboard/store/tekomi/preferences';
import TasksAPI from 'dashboard/api/tekomi/tasks';

/**
 * Cleans and normalizes a list of labels.
 * @param {string} labels - A comma-separated string of labels.
 * @returns {string[]} An array of cleaned and unique labels.
 */
const cleanLabels = labels => {
  return labels
    .toLowerCase()
    .split(',')
    .filter(label => label.trim())
    .map(label => label.trim())
    .filter((label, index, self) => self.indexOf(label) === index);
};

export function useLabelSuggestions() {
  const { isCloudFeatureEnabled } = useAccount();
  const tekomiConfigStore = useTekomiConfigStore();
  const { features } = storeToRefs(tekomiConfigStore);
  const currentChat = useMapGetter('getSelectedChat');
  const conversationId = computed(() => currentChat.value?.id);

  const tekomiTasksEnabled = computed(() => {
    return isCloudFeatureEnabled(FEATURE_FLAGS.TEKOMI_TASKS);
  });

  const isLabelSuggestionFeatureEnabled = computed(
    () => !!features.value.label_suggestion?.enabled
  );

  /**
   * Gets label suggestions for the current conversation.
   * @returns {Promise<string[]>} An array of suggested labels.
   */
  const getLabelSuggestions = async () => {
    if (!conversationId.value) return [];

    try {
      const result = await TasksAPI.labelSuggestion(conversationId.value);
      const {
        data: { message: labels },
      } = result;
      return cleanLabels(labels);
    } catch {
      return [];
    }
  };

  onMounted(() => {
    if (!Object.keys(features.value).length) {
      tekomiConfigStore.fetch();
    }
  });

  return {
    tekomiTasksEnabled,
    isLabelSuggestionFeatureEnabled,
    getLabelSuggestions,
  };
}
```

- [ ] **Step 7: `en.yml`**

Xóa trong `errors:`:
```yaml
    openai:
      invalid_api_key: 'OpenAI API key is invalid or revoked. Please check your key in your OpenAI dashboard.'
```
Xóa trong `integration_apps:`:
```yaml
    openai:
      name: 'OpenAI'
      short_description: 'AI-powered reply suggestions, summarization, and message enhancement.'
      description: 'Leverage the power of large language models from OpenAI with the features such as reply suggestions, summarization, message rephrasing, spell-checking, and label classification.'
```

---

### Task 12: Dọn hằng số & kiểm tra tĩnh

**Files:**
- Modify: `lib/llm_constants.rb`
- Modify: `config/locales/en.yml` (`tekomi.api_key_missing`)

- [ ] **Step 1: `lib/llm_constants.rb`** — thay toàn bộ bằng:

```ruby
# frozen_string_literal: true

module LlmConstants
  PROVIDER_PREFIXES = {
    'openai' => %w[gpt- o1 o3 o4 text-embedding- whisper- tts-],
    'anthropic' => %w[claude-],
    'google' => %w[gemini-],
    'mistral' => %w[mistral- codestral-],
    'deepseek' => %w[deepseek-]
  }.freeze
end
```

- [ ] **Step 2: `en.yml`** — xóa dòng `    api_key_missing: 'Tekomi AI API key is not configured.'` trong `tekomi:`.

- [ ] **Step 3: Kiểm tra không còn tham chiếu cũ**

```bash
grep -rn "TEKOMI_OPEN_AI_\|TEKOMI_EMBEDDING_MODEL\|Llm::Models\|agent_model\|openai_file_id\|LegacyBaseOpenAiService\|use_account_openai_hook\|llm_credential\|tekomi_models\|GPT_MODEL\|DEFAULT_EMBEDDING_MODEL\|Llm::Config.initialize!\|OpenAI::Client\|KeyValidator" app enterprise lib config --include=*.rb --include=*.erb --include=*.yml --include=*.vue --include=*.js | grep -v "db/migrate\|locales/[a-z_]*[^n]\.yml"
```
Expected: không có kết quả.

- [ ] **Step 4: Lint**

```bash
bundle exec rubocop -a lib/llm lib/tekomi lib/custom_exceptions app/models enterprise/app/services enterprise/app/controllers/super_admin enterprise/app/jobs db/migrate
pnpm eslint:fix
```

---

## Sau khi triển khai (người dùng)

1. Backup DB, kiểm tra `.env` có `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`.
2. Deploy → `rails db:migrate`.
3. Super Admin → Settings → Tekomi AI → tab **AI features**: điền các dòng "Not configured" (vd `audio_transcription` khi dùng OpenRouter).
4. Tự kiểm thử theo kịch bản trong spec.
