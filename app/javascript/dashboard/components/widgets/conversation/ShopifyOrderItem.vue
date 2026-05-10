<script setup>
import { computed } from 'vue';
import { format } from 'date-fns';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const formatDate = dateString => {
  return format(new Date(dateString), 'MMM d, yyyy');
};

const formatCurrency = (amount, currency) => {
  return new Intl.NumberFormat('en', {
    style: 'currency',
    currency: currency || 'USD',
  }).format(amount);
};

const getStatusClass = status => {
  const classes = {
    paid: 'bg-n-teal-5 text-n-teal-12',
  };
  return classes[status] || 'bg-n-solid-3 text-n-slate-12';
};

const getStatusI18nKey = (type, status = '') => {
  return `CONVERSATION_SIDEBAR.SHOPIFY.${type.toUpperCase()}_STATUS.${status.toUpperCase()}`;
};

const fulfillmentStatus = computed(() => {
  const { fulfillment_status: status } = props.order;
  if (!status) {
    return '';
  }
  return t(getStatusI18nKey('FULFILLMENT', status));
});

const financialStatus = computed(() => {
  const { financial_status: status } = props.order;
  if (!status) {
    return '';
  }
  return t(getStatusI18nKey('FINANCIAL', status));
});

const orderDisplayId = computed(() => props.order.name || props.order.id);

const trackingItems = computed(() => props.order.tracking || []);

const trackingKey = (tracking, index) => {
  return [tracking.company, tracking.number, tracking.url, index]
    .filter(Boolean)
    .join('-');
};

const formatTrackingStatus = status => {
  if (!status) {
    return '';
  }
  return status.replace(/_/g, ' ');
};

const getFulfillmentClass = status => {
  const classes = {
    fulfilled: 'text-n-teal-9',
    partial: 'text-n-amber-9',
    unfulfilled: 'text-n-ruby-9',
  };
  return classes[status] || 'text-n-slate-11';
};
</script>

<template>
  <div
    class="py-3 border-b border-n-weak last:border-b-0 flex flex-col gap-1.5"
  >
    <div class="flex justify-between items-center gap-2">
      <div class="font-medium flex min-w-0">
        <a
          :href="order.admin_url"
          target="_blank"
          rel="noopener noreferrer"
          class="hover:underline text-n-slate-12 cursor-pointer truncate"
        >
          {{ $t('CONVERSATION_SIDEBAR.SHOPIFY.ORDER_ID', { id: orderDisplayId }) }}
          <i class="i-lucide-external-link pl-5" />
        </a>
      </div>
      <div
        :class="getStatusClass(order.financial_status)"
        class="text-xs px-2 py-1 rounded capitalize truncate flex-shrink-0"
        :title="financialStatus"
      >
        {{ financialStatus }}
      </div>
    </div>
    <div class="text-sm text-n-slate-12">
      <span class="text-n-slate-11 border-r border-n-weak pr-2">
        {{ formatDate(order.created_at) }}
      </span>
      <span class="text-n-slate-11 pl-2">
        {{ formatCurrency(order.total_price, order.currency) }}
      </span>
    </div>
    <div v-if="fulfillmentStatus">
      <span
        :class="getFulfillmentClass(order.fulfillment_status)"
        class="capitalize font-medium"
        :title="fulfillmentStatus"
      >
        {{ fulfillmentStatus }}
      </span>
    </div>
    <div
      v-if="trackingItems.length"
      class="mt-1 flex flex-col gap-2 rounded-md bg-n-alpha-2 p-2 text-sm"
    >
      <div
        v-for="(tracking, index) in trackingItems"
        :key="trackingKey(tracking, index)"
        class="flex flex-col gap-1"
      >
        <div
          v-if="tracking.company"
          class="flex items-center gap-1 font-medium text-n-slate-12 min-w-0"
        >
          <i class="i-lucide-truck text-n-slate-11 flex-shrink-0" />
          <span class="truncate">{{ tracking.company }}</span>
        </div>
        <div v-if="tracking.number" class="text-n-slate-11 break-all">
          Codigo:
          <span class="font-mono text-n-slate-12">{{ tracking.number }}</span>
        </div>
        <div
          v-if="tracking.shipment_status"
          class="capitalize text-xs text-n-slate-11"
        >
          {{ formatTrackingStatus(tracking.shipment_status) }}
        </div>
        <a
          v-if="tracking.url"
          :href="tracking.url"
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex items-center gap-1 text-n-blue-11 hover:underline w-fit"
        >
          Abrir rastreio
          <i class="i-lucide-external-link" />
        </a>
      </div>
    </div>
  </div>
</template>
