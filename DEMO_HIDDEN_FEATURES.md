# ⚠️ Sidebar tạm ẩn tính năng để demo khách hàng

**Ngày ẩn:** 2026-09-07
**Lý do:** Demo Dashboard cho khách hàng, chỉ hiển thị đúng những tính năng đã có trong tài liệu `Tekomi_Connect.docx` (mục 4.1 → 4.8). Các tính năng khác trong sản phẩm thật vẫn tồn tại và hoạt động bình thường — chỉ bị **ẩn khỏi sidebar**, không xoá, không tắt logic.

**File đã sửa:** `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`
(tìm comment `TEMP DEMO FILTER` gần cuối hàm `menuItems`)

## Cách khôi phục lại sidebar đầy đủ

Mở file trên, tìm dòng:

```js
const DEMO_MODE = true;
```

Đổi thành:

```js
const DEMO_MODE = false;
```

Lưu lại — toàn bộ sidebar sẽ trở về đầy đủ như cũ ngay lập tức. Sau khi xác nhận ổn, có thể xoá luôn cả khối code `TEMP DEMO FILTER` (từ dòng comment `====` đầu tiên đến hết) và đổi dòng `const items = [` ở đầu hàm `menuItems` lại thành `return [` để dọn sạch code.

## Danh sách đã ẩn

**Menu cấp cao (5 mục):**
- Tekomi AI (tên nội bộ trong code vẫn là `Captain`, không đổi — chỉ tên hiển thị đã đổi từ 1 commit trước)
- Calls
- Companies
- Reports
- Portals (Help Center)

**Menu con trong Settings (11 mục):**
- Account Settings
- Agents
- Teams
- Templates (WhatsApp)
- Custom Attributes
- Data (Import/Export)
- Audit Logs
- Custom Roles
- Conversation Workflow
- Security
- Billing

**Giữ lại (khớp đúng tài liệu demo):** Inboxes, Labels, Automation, Agent Bots, Macros, Canned Responses, Integrations, SLA, Agent Assignment, Conversation, Contacts, Campaigns, Home, Inbox.

## Lưu ý cho phiên Claude Code sau

Nếu người dùng nhắc "khôi phục sidebar", "bỏ chế độ demo", hoặc tương tự — đọc file này trước, thực hiện đúng bước "Cách khôi phục" ở trên, sau đó **xoá file `DEMO_HIDDEN_FEATURES.md` này** vì nó chỉ có giá trị tạm thời.
