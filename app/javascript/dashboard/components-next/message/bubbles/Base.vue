<script setup>
import { computed } from 'vue';

import MessageMeta from '../MessageMeta.vue';
import TekomiGenerationDetails from '../TekomiGenerationDetails.vue';

import { emitter } from 'shared/helpers/mitt';
import { useMessageContext } from '../provider.js';
import { useI18n } from 'vue-i18n';

import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { MESSAGE_VARIANTS, ORIENTATION, SENDER_TYPES } from '../constants';

const props = defineProps({
  hideMeta: { type: Boolean, default: false },
});

const {
  variant,
  orientation,
  inReplyTo,
  shouldGroupWithNext,
  id,
  sender,
  senderType,
} = useMessageContext();
const { t } = useI18n();

const isTekomiMessage = computed(
  () =>
    (sender.value?.type ?? senderType.value) === SENDER_TYPES.TEKOMI_ASSISTANT
);

const metaColorClass = computed(() => {
  if (variant.value === MESSAGE_VARIANTS.PRIVATE) return 'text-n-amber-12/50';
  if (variant.value === MESSAGE_VARIANTS.AGENT) return 'text-white/70';
  return 'text-n-slate-11';
});

const emailMetaClass = computed(() =>
  variant.value === MESSAGE_VARIANTS.EMAIL ? 'px-3 pb-3' : ''
);

const varaintBaseMap = {
  [MESSAGE_VARIANTS.AGENT]:
    'bg-[#3B82F6] text-white shadow-[0_1px_2px_rgba(59,130,246,0.3)] [&_.prose]:text-white [&_.prose_*]:!text-white [&_a]:underline',
  [MESSAGE_VARIANTS.PRIVATE]:
    'bg-n-solid-amber border border-n-amber-6 text-n-amber-12 shadow-sm [&_.prosemirror-mention-node]:font-semibold',
  [MESSAGE_VARIANTS.USER]:
    'bg-white border border-n-weak text-n-slate-12 shadow-[0_1px_2px_rgba(16,24,40,0.06)] dark:bg-n-slate-4 dark:border-transparent',
  [MESSAGE_VARIANTS.ACTIVITY]: 'bg-n-alpha-1 text-n-slate-11 text-sm',
  [MESSAGE_VARIANTS.BOT]:
    'bg-white border border-n-weak text-n-slate-12 shadow-[0_1px_2px_rgba(16,24,40,0.06)]',
  [MESSAGE_VARIANTS.TEMPLATE]:
    'bg-white border border-n-weak text-n-slate-12 shadow-[0_1px_2px_rgba(16,24,40,0.06)]',
  [MESSAGE_VARIANTS.ERROR]: 'bg-n-ruby-4 text-n-ruby-12',
  [MESSAGE_VARIANTS.EMAIL]: 'w-full',
  [MESSAGE_VARIANTS.UNSUPPORTED]:
    'bg-n-solid-amber/70 border border-dashed border-n-amber-12 text-n-amber-12',
};

const orientationMap = {
  [ORIENTATION.LEFT]:
    'left-bubble rounded-2xl ltr:rounded-bl-md rtl:rounded-br-md',
  [ORIENTATION.RIGHT]:
    'right-bubble rounded-2xl ltr:rounded-br-md rtl:rounded-bl-md',
  [ORIENTATION.CENTER]: 'rounded-lg',
};

const flexOrientationClass = computed(() => {
  const map = {
    [ORIENTATION.LEFT]: 'justify-start',
    [ORIENTATION.RIGHT]: 'justify-end',
    [ORIENTATION.CENTER]: 'justify-center',
  };

  return map[orientation.value];
});

const messageClass = computed(() => {
  const classToApply = [varaintBaseMap[variant.value]];

  if (variant.value !== MESSAGE_VARIANTS.ACTIVITY) {
    classToApply.push(orientationMap[orientation.value]);
  } else {
    classToApply.push('rounded-lg');
  }

  return classToApply;
});

const scrollToMessage = () => {
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, {
    messageId: inReplyTo.value.id,
  });
};

const shouldShowMeta = computed(
  () =>
    !props.hideMeta &&
    !shouldGroupWithNext.value &&
    variant.value !== MESSAGE_VARIANTS.ACTIVITY
);

const replyToPreview = computed(() => {
  if (!inReplyTo) return '';

  const { content, attachments } = inReplyTo.value;

  if (content) return new MessageFormatter(content).formattedMessage;
  if (attachments?.length) {
    const firstAttachment = attachments[0];
    const fileType = firstAttachment.fileType ?? firstAttachment.file_type;

    return t(`CHAT_LIST.ATTACHMENTS.${fileType}.CONTENT`);
  }

  return t('CONVERSATION.REPLY_MESSAGE_NOT_FOUND');
});
</script>

<template>
  <div
    class="text-sm min-w-0"
    :class="[
      messageClass,
      {
        'max-w-lg': variant !== MESSAGE_VARIANTS.EMAIL,
      },
    ]"
  >
    <div
      v-if="inReplyTo"
      class="p-2 -mx-1 mb-2 rounded-lg cursor-pointer bg-n-alpha-black1"
      @click="scrollToMessage"
    >
      <div
        v-dompurify-html="replyToPreview"
        class="prose prose-bubble line-clamp-2"
      />
    </div>
    <slot />
    <template v-if="shouldShowMeta">
      <TekomiGenerationDetails
        v-if="isTekomiMessage"
        :message-id="id"
        class="mt-2"
      >
        <template #meta>
          <MessageMeta :class="[emailMetaClass, metaColorClass]" />
        </template>
      </TekomiGenerationDetails>
      <MessageMeta
        v-else
        :class="[flexOrientationClass, emailMetaClass, metaColorClass]"
        class="mt-2"
      />
    </template>
  </div>
</template>
