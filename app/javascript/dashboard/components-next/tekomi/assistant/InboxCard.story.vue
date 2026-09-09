<script setup>
import InboxCard from './InboxCard.vue';
import { inboxes } from 'dashboard/components-next/tekomi/pageComponents/emptyStates/tekomiEmptyStateContent.js';
</script>

<template>
  <Story
    title="Tekomi/Assistant/InboxCard"
    :layout="{ type: 'grid', width: '700px' }"
  >
    <Variant title="Inbox Card">
      <div
        v-for="inbox in inboxes"
        :key="inbox.id"
        class="px-20 py-4 bg-n-background"
      >
        <InboxCard :id="inbox.id" :inbox="inbox" />
      </div>
    </Variant>
  </Story>
</template>
