# == Schema Information
#
# Table name: tekomi_inboxes
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  inbox_id            :bigint           not null
#  tekomi_assistant_id :bigint           not null
#
# Indexes
#
#  index_tekomi_inboxes_on_inbox_id                          (inbox_id)
#  index_tekomi_inboxes_on_tekomi_assistant_id               (tekomi_assistant_id)
#  index_tekomi_inboxes_on_tekomi_assistant_id_and_inbox_id  (tekomi_assistant_id,inbox_id) UNIQUE
#
class TekomiInbox < ApplicationRecord
  belongs_to :tekomi_assistant, class_name: 'Tekomi::Assistant'
  belongs_to :inbox

  validates :inbox_id, uniqueness: true
end
