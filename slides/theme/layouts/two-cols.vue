<template>
  <div class="slidev-layout two-cols">
    <div class="itmo-cols">
      <div class="itmo-col"><slot /></div>
      <div class="itmo-col"><slot name="right" /></div>
    </div>
    <ItmoFooter />
  </div>
</template>
