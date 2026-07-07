<script setup lang="ts">
import { useSlideContext } from '@slidev/client'

const { $page, $slidev } = useSlideContext()
</script>

<template>
  <footer class="itmo-footer">
    <span>{{ $slidev.configs.title }}</span>
    <span>{{ $page }} / {{ $slidev.nav.total }}</span>
  </footer>
</template>
