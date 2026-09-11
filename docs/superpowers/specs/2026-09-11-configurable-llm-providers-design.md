# Cấu hình Provider & Model AI từ Super Admin — Thiết kế

- **Ngày:** 2026-09-11
- **Trạng thái:** Đã duyệt thiết kế, chưa triển khai
- **Phạm vi:** Toàn bộ tính năng Tekomi AI (OSS `lib/`, `app/` và `enterprise/`)

## 1. Bối cảnh & mục tiêu

### Vấn đề hiện tại
- Provider AI bị cố định là OpenAI: một bộ `TEKOMI_OPEN_AI_API_KEY` / `TEKOMI_OPEN_AI_MODEL` / `TEKOMI_OPEN_AI_ENDPOINT` trong InstallationConfig.
- Tên model bị hardcode rải rác: `config/llm.yml`, `LlmConstants`, `Llm::Config::DEFAULT_MODEL`, `Llm::FeatureRouter::TEKOMI_V2_ASSISTANT_MODEL`, `DETECTOR_MODEL`, `AUDITOR_MODEL`, `CLASSIFIER_MODEL`, `CURATION_MODEL`, `gpt-4o` trong `article.rb`, `LegacyBaseOpenAiService::DEFAULT_MODEL`.
- Khi dùng OpenRouter qua endpoint OpenAI với model có tiền tố (`openai/...`), RubyLLM tra registry `config/llm_models.json`, nhận diện model thuộc provider `openrouter` và đòi `openrouter_api_key` → `RubyLLM::ConfigurationError`. Lỗi này làm Trợ thủ (Copilot) treo ở trạng thái "đang suy nghĩ" (job lỗi, không có tin trả lời được lưu).
- Nhiều tính năng dùng tên model mặc định không có tiền tố, không tương thích OpenRouter.

### Mục tiêu
- Không hardcode model và provider trong code.
- Super Admin tự cấu hình: nhiều provider (OpenRouter, DeepSeek, OpenAI, Anthropic, Gemini, …) và chọn provider + model cho **từng** tính năng AI.
- Thay đổi cấu hình có hiệu lực ngay, không cần restart.

### Quyết định đã chốt
| Chủ đề | Quyết định |
|---|---|
| Kiểu provider | Nhiều provider cùng lúc; mỗi tính năng chọn provider riêng |
| Nơi cấu hình | **Chỉ Super Admin** (bỏ lựa chọn model ở cấp account) |
| Danh sách model | Admin **nhập tay** tên model |
| Lưu trữ | **Bảng DB riêng**, API key mã hóa |
| Nhóm Soạn thảo | **Tách riêng** từng tính năng |
| Integration OpenAI (Settings → Tích hợp) | **Bỏ** |
| Tính năng chưa cấu hình | Hiện trên trang Admin là "Chưa cấu hình"; khi gọi thì báo lỗi rõ ràng, không fallback |
| PDF | Viết lại: gửi PDF kèm trực tiếp trong request qua RubyLLM (bỏ OpenAI Files API) |
| Kiểm thử | Người dùng tự kiểm thử; không viết spec mới. Spec của file bị xóa thì xóa theo, spec khác để nguyên |

### Ngoài phạm vi
- Temperature / max tokens / bật-tắt theo từng tính năng.
- Nút "Kiểm tra kết nối", tự lấy danh sách model từ API provider, lịch sử thay đổi cấu hình.
- Cắt trang PDF để giảm token.

## 2. Dữ liệu

### Bảng `llm_providers`
| Cột | Kiểu | Ràng buộc |
|---|---|---|
| `name` | string | not null, unique — tên hiển thị |
| `provider_type` | string | not null, **unique** — `openai`, `openrouter`, `deepseek`, `anthropic`, `gemini`, `mistral`, `xai`, `ollama` |
| `api_key` | text | `encrypts`; bắt buộc trừ `ollama` |
| `api_base` | string | tùy chọn; nhập đầy đủ kèm phần version (vd `https://openrouter.ai/api/v1`); bắt buộc với `ollama`; không hỗ trợ với `mistral`, `xai`; trống = mặc định của provider |

**Mỗi `provider_type` tối đa 1 dòng.** Lý do: bot V2 chạy qua `ai-agents`, gem này tạo `RubyLLM::Chat.new(model:, provider:, assume_model_exists:)` không nhận context riêng nên chỉ đọc cấu hình RubyLLM toàn cục (mỗi loại provider một key). Endpoint tương thích OpenAI khác dùng loại `openai` + `api_base`.

### Bảng `llm_feature_models`
| Cột | Kiểu | Ràng buộc |
|---|---|---|
| `feature_key` | string | not null, unique |
| `llm_provider_id` | FK → `llm_providers` | not null, `on_delete: :restrict` |
| `model` | string | not null |

Cả hai bảng áp dụng toàn hệ thống (không có `account_id`). Model ActiveRecord đặt ở `app/models/` vì cả OSS (`lib/tekomi`) và Enterprise đều dùng.

### Danh sách tính năng (trong code)
`config/llm.yml` bỏ `models`, bỏ `default`; mỗi feature chỉ còn `group`, đọc qua module mới `Llm::Features` (thay `Llm::Models`). Cột Capability bên dưới chỉ để tham khảo, không lưu trong config.

| Nhóm | `feature_key` | Dùng bởi | Capability |
|---|---|---|---|
| Soạn thảo | `reply_suggestion` | `Tekomi::ReplySuggestionService` | chat |
| Soạn thảo | `summary` | `Tekomi::SummaryService` | chat |
| Soạn thảo | `rewrite` | `Tekomi::RewriteService` | chat |
| Soạn thảo | `follow_up` | `Tekomi::FollowUpService` | chat |
| Soạn thảo | `overview_summary` | `Tekomi::OverviewSummaryService`, `Tekomi::AssistantOverviewSummaryService` | chat |
| Soạn thảo | `csat_analysis` | `Tekomi::CsatUtilityAnalysisService` | chat |
| Trợ thủ | `copilot` | `Tekomi::Copilot::ChatService` | chat |
| Bot | `assistant` | `AssistantChatService`, bot V2 (`Agentable`, `ResponseRewriter`), `ContactNotesService`, `ContactAttributesService`, `AssistantActionClassifierService` | chat |
| Bot | `false_promise_detection` | `AssistantFalsePromiseService` | chat |
| Bot | `instruction_migration` | `AssistantMigration::InstructionAuditor`, `InstructionClassifier` | chat |
| Hội thoại | `label_suggestion` | `Tekomi::LabelSuggestionService` | chat |
| Hội thoại | `conversation_completion` | `Tekomi::ConversationCompletionService` | chat |
| FAQ | `document_faq_generation` | `FaqGeneratorService` | chat |
| FAQ | `pdf_faq_generation` | `PaginatedFaqGeneratorService` | chat (cần đọc PDF) |
| FAQ | `conversation_faq_generation` | `ConversationFaqService` (tạo) | chat |
| FAQ | `conversation_faq_matching` | `ConversationFaqService` (khớp) | chat |
| Help Center | `help_center_article_generation` | `ArticleWriterService`, `ArticleTranslationService` | chat |
| Help Center | `help_center_query_translation` | `TranslateQueryService` | chat |
| Help Center | `help_center_curation` | `HelpCenterCurationService` | chat |
| Help Center | `article_search_terms` | `Enterprise::Concerns::Article#generate_article_search_terms` | chat |
| Onboarding | `onboarding_content_generation` | `WebsiteAnalyzerService`, `WidgetTaglineService` | chat |
| Embedding | `embedding` | `Tekomi::Llm::EmbeddingService` | embedding |
| Âm thanh | `audio_transcription` | `Llm::SpeechToTextService` | transcription |

## 3. Giao diện Super Admin

**Lối vào:** Super Admin → Settings → thẻ Tekomi AI → trang cấu hình AI gồm 2 tab (Tính năng AI, Providers) và 1 tab liên kết FireCrawl. Form app_config `tekomi` cũ chỉ còn `TEKOMI_FIRECRAWL_API_KEY`.

### Tab Providers
- Bảng: Tên | Loại | Endpoint | API Key (chỉ hiện 4 ký tự cuối) | Số tính năng đang dùng | Sửa · Xóa.
- Form thêm/sửa: Tên, Loại (dropdown; chọn loại đã có sẽ báo lỗi validation), API Key (password; khi sửa để trống = giữ key cũ), Endpoint.
- Xóa bị khóa khi còn tính năng dùng provider.

### Tab Tính năng AI
- Bảng nhóm theo `group`; mỗi dòng: tên + mô tả ngắn | Provider (dropdown) | Model (text) | Trạng thái (Đã cấu hình / Chưa cấu hình). Một nút Lưu cho cả bảng.
- Dòng tổng hợp đầu trang: "N tính năng chưa cấu hình".
- Cảnh báo cố định:
  - `embedding`: model phải trả vector **1536 chiều** (cột `vector(1536)` ở 3 bảng); đổi số chiều cần migration + tạo lại embedding.
  - `audio_transcription`: provider phải hỗ trợ API chuyển giọng nói (RubyLLM: OpenAI, Gemini, VertexAI; OpenRouter có `/audio/transcriptions` tương thích OpenAI).
  - `pdf_faq_generation`: nên dùng model đọc PDF native (vd `openai/gpt-4.1-mini`); model không đọc PDF native trên OpenRouter sẽ bị tính phí OCR theo trang cho mỗi request.

### Kỹ thuật
- Trang ERB trong Super Admin, controller ở `enterprise/app/controllers/super_admin/`, theo pattern `SuperAdmin::EnterpriseBaseController`.
- Chuỗi hiển thị qua `en.yml`.

### Phía account
- Settings → Tekomi: bỏ phần chọn model (`ModelDropdown`), giữ bật/tắt tính năng.
- Settings → Tích hợp: bỏ thẻ OpenAI.
- Gợi ý nhãn trong hội thoại bật/tắt theo nút Label Suggestion ở Settings → Tekomi (trước đây theo cài đặt `label_suggestion` của Integration OpenAI).
- `tekomi_features` (bật/tắt theo account) dùng danh sách key riêng `TekomiFeaturable::TOGGLE_FEATURE_KEYS = label_suggestion, help_center_search, audio_transcription`, tách khỏi danh sách tính năng chọn model.

## 4. Luồng gọi AI

```
Service
  └─ Llm::FeatureRouter.resolve(feature:)
       ├─ đọc llm_feature_models (+ provider)
       ├─ chưa cấu hình → raise CustomExceptions::Llm::FeatureNotConfigured
       └─ trả { provider_type:, model: }
  └─ Llm::Config.apply!
       └─ nếu khóa phiên bản trong cache thay đổi → RubyLLM.configure từ llm_providers
          (<type>_api_key, <type>_api_base; model_registry_file giữ nguyên)
  └─ RubyLLM.chat / embed / transcribe(model:, provider: provider_type, assume_model_exists: true)
```

- `LlmProvider` và `LlmFeatureModel` `after_commit` → tăng khóa phiên bản trong `Rails.cache`. Mỗi process (Puma, Sidekiq) so khóa trước khi gọi AI và chỉ nạp lại khi khác → đổi cấu hình không cần restart.
- Luôn truyền `provider:` + `assume_model_exists: true` → RubyLLM không tra registry, dùng đúng key/endpoint Admin nhập.

### Các điểm gọi cần chuyển
| Điểm gọi | Thay đổi |
|---|---|
| `Llm::BaseAiService` (`setup_model`, `#chat`) | Lấy provider/model từ router; bỏ `DEFAULT_MODEL`, `fallback_model`, `installation_model` |
| `Tekomi::BaseTaskService` (`resolved_model`, `build_chat`, `llm_credential`) | Lấy từ router; bỏ `provider: :openai` cố định, bỏ hook credential; dùng cấu hình toàn cục thay vì `Llm::Config.with_api_key` |
| `Tekomi::Llm::EmbeddingService` | Lấy từ router feature `embedding`; bỏ `TEKOMI_EMBEDDING_MODEL` |
| `Agentable#agent_model` + `Agents::Agent.new`, `Tekomi::Assistant::ResponseRewriter` | Truyền `model`, `provider`, `assume_model_exists: true` (ai-agents 0.12.0 đã hỗ trợ) |
| `Llm::SpeechToTextService` | Chuyển từ `ruby-openai` sang `RubyLLM.transcribe(model:, provider:)` |
| `Enterprise::Concerns::Article#generate_article_search_terms` | Bỏ HTTParty + `gpt-4o`; gọi RubyLLM qua feature `article_search_terms` |
| `AssistantFalsePromiseService`, `InstructionAuditor`, `InstructionClassifier`, `HelpCenterCurationService` | Bỏ hằng số model; dùng feature tương ứng |
| `config/initializers/ai_agents.rb` | Xóa; thay bằng `Llm::Config.apply!` |

### Luồng PDF mới
1. Bỏ upload lên OpenAI Files API; đọc PDF từ ActiveStorage (giới hạn 10MB giữ nguyên).
2. `PaginatedFaqGeneratorService`: mỗi nhóm trang gọi `chat.ask(prompt trang X–Y, with: file PDF)` qua RubyLLM với feature `pdf_faq_generation`. RubyLLM gửi PDF dạng `type: 'file'` + base64 (`OpenRouter`, `DeepSeek` kế thừa `OpenAI` trong RubyLLM — xác minh bằng request thật khi triển khai).
3. `Tekomi::Documents::ResponseBuilderJob#should_use_pagination?` dùng `document.pdf_file.attached?` (link `.pdf` ngoài không có file upload vẫn đi luồng FAQ thường như trước).
4. Đánh đổi đã chấp nhận: mỗi nhóm trang gửi lại toàn bộ file (tốn token/phí OCR hơn với PDF dài).

## 5. Chuyển dữ liệu & dọn code

### Migration
1. **Schema:** tạo `llm_providers`, `llm_feature_models`.
2. **Dữ liệu** (theo pattern `db/migrate/20260909000004_remove_stale_captain_feature_defaults.rb`):
   - Không có `TEKOMI_OPEN_AI_API_KEY` → bỏ qua (mọi tính năng "Chưa cấu hình").
   - Tạo provider từ `TEKOMI_OPEN_AI_ENDPOINT`: host `openrouter.ai` → `openrouter`; trống hoặc `api.openai.com` → `openai`; khác → `openai` + `api_base`.
   - Tạo `llm_feature_models` theo model đang chạy:
     - `copilot`, `assistant`, `conversation_completion` → `TEKOMI_OPEN_AI_MODEL` nếu có.
     - `embedding` → `TEKOMI_EMBEDDING_MODEL` hoặc `text-embedding-3-small`.
     - Tính năng khác → model mặc định/hardcode hiện tại (`llm.yml` default, `gpt-5.2` cho bot V2 / false promise / instruction migration, `gpt-4.1` cho curation, `gpt-4o` cho article search terms, `gpt-4.1-mini` cho PDF).
     - Provider `openrouter` và tên model chưa có `/` → thêm tiền tố `openai/`.
     - `audio_transcription` chỉ tạo khi provider là `openai`; ngược lại để "Chưa cấu hình".
   - API key ghi qua model có `encrypts`; thiếu `ACTIVE_RECORD_ENCRYPTION_*` → migration báo lỗi và dừng.
3. **Xóa dữ liệu cũ:** InstallationConfig `TEKOMI_OPEN_AI_API_KEY`, `TEKOMI_OPEN_AI_MODEL`, `TEKOMI_OPEN_AI_ENDPOINT`, `TEKOMI_EMBEDDING_MODEL`; key `tekomi_models` trong `accounts.settings`; `Integrations::Hook` có `app_id: 'openai'`.
4. Migration dữ liệu **không đảo ngược** (`ActiveRecord::IrreversibleMigration`).

### Dọn code
| Nhóm | Hạng mục |
|---|---|
| Model hardcode | `config/llm.yml` (models/default), `LlmConstants::DEFAULT_MODEL`, `DEFAULT_EMBEDDING_MODEL`, `PDF_PROCESSING_MODEL`, `OPENAI_API_ENDPOINT`, `Llm::Config::DEFAULT_MODEL`, `Llm::FeatureRouter::TEKOMI_V2_ASSISTANT_MODEL`, hằng số model trong 4 service, `gpt-4o` trong `article.rb`, `Llm::Models` (phần models/provider_for/valid_model_for?/feature_config) |
| Model theo account | `Account` `store_accessor :tekomi_models`, `TekomiFeaturable` (phần models), `AccountSettingsSchema`, `AccountDashboard` + `TekomiModelOverridesField`, `SuperAdmin::AccountsController` param, `PreferencesController` (phần models/providers), frontend Settings → Tekomi phần model, `ModelDropdown.vue`, store `tekomi/preferences.js` phần models |
| Integration OpenAI | `openai` trong `config/integration/apps.yml`, phần OpenAI trong `NewHook.vue`, `Integrations::Hook#validate_openai_api_key`, `Integrations::Openai::KeyValidator`, `Migration::ValidateOpenaiHooksJob`, `Integrations::LlmBaseService` (không còn subclass), `use_account_openai_hook?` / `hook_llm_credential` / `openai_hook` trong `BaseTaskService` và 8 service con |
| Legacy | `Llm::LegacyBaseOpenAiService`, `Tekomi::Llm::PdfProcessingService`, gem `ruby-openai`, `config/initializers/ai_agents.rb`, `openai_file_id` (`Tekomi::Document`) |
| Super Admin | `SuperAdmin::AppConfigsController` `tekomi` chỉ còn `TEKOMI_FIRECRAWL_API_KEY`; bỏ các mục tương ứng trong `config/installation_config.yml` |
| Enterprise | Với mỗi file OSS bị sửa, kiểm tra override trong `enterprise/` (vd `enterprise/app/controllers/enterprise/super_admin/app_configs_controller.rb`) |
| i18n | Chỉ `en.yml`, `en.json` |
| Spec | Xóa spec của file bị xóa; spec khác để nguyên (người dùng tự xử lý) |

### Checklist server trước khi deploy
1. Backup DB.
2. `.env` có `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`.
3. Kiểm tra account nào đang bật Integration OpenAI (key sẽ bị xóa).
4. Sau deploy: vào tab Tính năng AI điền các dòng "Chưa cấu hình".

### Rủi ro lâu dài
Các file AI khác nhiều so với Chatwoot upstream → merge upstream dễ xung đột ở phần AI.

## 6. Xử lý lỗi

- **Lỗi mới:** `CustomExceptions::Llm::FeatureNotConfigured` (`lib/custom_exceptions/llm.rb`, theo pattern `pdf.rb`), raise trong `Llm::FeatureRouter.resolve` với tên tính năng. Không fallback model.
- **Theo luồng:**

| Tính năng | Hành vi |
|---|---|
| Soạn thảo | Giữ cơ chế bắt lỗi hiện có, trả lỗi về UI; nội dung thông báo nêu rõ tính năng chưa cấu hình |
| Bot trả lời khách | Giữ `handle_error` → handoff cho nhân viên |
| Trợ thủ | `Tekomi::Copilot::ResponseJob` bắt lỗi → lưu 1 `CopilotMessage` `assistant` với `content` rỗng (UI sẵn có hiển thị `TEKOMI.COPILOT.EMPTY_MESSAGE`) và ghi log/exception tracker; **không** re-raise nên Sidekiq không retry (RubyLLM đã tự retry lỗi mạng) |
| PDF / embedding / transcription | Giữ cơ chế lỗi hiện có của từng job; thông báo rõ khi chưa cấu hình |

- **Validation Super Admin:**
  - `LlmProvider`: `provider_type` thuộc danh sách và unique; `api_key` bắt buộc trừ `ollama`; `api_base` bắt buộc với `ollama`; không xóa khi còn `llm_feature_models` (FK restrict + thông báo).
  - `LlmFeatureModel`: `feature_key` thuộc danh sách trong `llm.yml`; provider và model cùng có hoặc cùng trống (trống = xóa dòng); `model` được strip.
  - Cảnh báo capability chỉ hiển thị, không chặn lưu.
