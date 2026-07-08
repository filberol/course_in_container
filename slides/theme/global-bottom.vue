<!--
  Runs on every slide. Two jobs, both impossible to do from plain theme CSS
  because Slidev renders each Mermaid diagram inside a Shadow DOM:

  1. Auto-fit: size every diagram's <svg> to the real space available on its
     slide (capped at the diagram's natural size), so decks never need manual
     per-diagram `{scale: …}` tuning and diagrams stop overflowing.
  2. Round the diagram node shapes to match the card/table radius of the theme,
     by injecting a <style> into each diagram's shadow root.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue'

const anchor = ref<HTMLElement>()

// Injected inside each Mermaid shadow root (CSS can't cross the boundary).
const ROUNDING = `
  .node rect, .node circle, rect.actor, .actor > rect,
  g.classGroup rect, .entityBox, .attributeBoxOdd, .attributeBoxEven,
  .note rect, rect.note, .labelBox, .stateGroup rect, .er .entityBox {
    rx: 6px; ry: 6px;
  }
  .cluster rect, .cluster-inner, .nodeLabel .cluster { rx: 11px; ry: 11px; }
`

function fitOne(host: Element): boolean {
  const shadow = (host as HTMLElement & { shadowRoot: ShadowRoot | null }).shadowRoot
  if (!shadow) return false
  const svg = shadow.querySelector('svg') as SVGSVGElement | null
  if (!svg) return false

  // one-time: round the shapes inside this diagram
  if (!shadow.querySelector('style[data-itmo-round]')) {
    const st = document.createElement('style')
    st.setAttribute('data-itmo-round', '')
    st.textContent = ROUNDING
    shadow.appendChild(st)
  }

  const layout = host.closest('.slidev-layout') as HTMLElement | null
  if (!layout) return false

  const vb = (svg.getAttribute('viewBox') || '').split(/[\s,]+/).map(Number)
  if (vb.length < 4 || !vb[2] || !vb[3]) return false
  const natW = vb[2]
  const natH = vb[3]

  // The layout is vertically centred (justify-content: center). Measuring the
  // diagram's position while centred would feed the diagram's own height back
  // into the available-height calc. So top-align the layout just for the
  // measurement, then restore centring for the final (now correctly sized)
  // render.
  const prevJustify = (layout as HTMLElement).style.justifyContent
  ;(layout as HTMLElement).style.justifyContent = 'flex-start'

  // available height: from the diagram's top down to the usable bottom of the
  // slide (layout content box minus its bottom padding, which also clears the
  // footer). All in unscaled layout px (offsetTop / clientHeight), so the
  // slide's CSS transform scale does not distort the math.
  const lcs = getComputedStyle(layout)
  const innerBottom = layout.clientHeight - (parseFloat(lcs.paddingBottom) || 0)
  let top = 0
  let n: HTMLElement | null = host as HTMLElement
  while (n && n !== layout) {
    top += n.offsetTop
    n = n.offsetParent as HTMLElement | null
  }
  const availH = Math.max(80, innerBottom - top - 6)

  // available width: content box of the diagram's column
  const parent = (host.parentElement || layout) as HTMLElement
  const pcs = getComputedStyle(parent)
  const availW = Math.max(
    120,
    parent.clientWidth - (parseFloat(pcs.paddingLeft) || 0) - (parseFloat(pcs.paddingRight) || 0),
  )

  ;(layout as HTMLElement).style.justifyContent = prevJustify

  // fit within the box, never upscale past the diagram's natural size
  const s = Math.min(availW / natW, availH / natH, 1)
  const w = Math.max(1, Math.round(natW * s))
  const h = Math.max(1, Math.round(natH * s))
  svg.setAttribute('width', String(w))
  svg.setAttribute('height', String(h))
  svg.style.maxWidth = `${w}px`
  svg.style.maxHeight = `${h}px`

  ;(host as HTMLElement).dataset.itmoFit = '1'
  return true
}

function pass(): boolean {
  const hosts = Array.from(document.querySelectorAll('.mermaid'))
  let allDone = hosts.length > 0
  for (const host of hosts) {
    if ((host as HTMLElement).dataset.itmoFit === '1') continue
    if (!fitOne(host)) allDone = false
  }
  return allDone
}

onMounted(() => {
  // Mermaid renders asynchronously into its shadow root; retry across frames
  // until every diagram on the page is sized (or we give up after ~1s).
  let tries = 0
  const tick = () => {
    const done = pass()
    if (!done && tries++ < 60) requestAnimationFrame(tick)
  }
  requestAnimationFrame(tick)
})
</script>

<template>
  <span ref="anchor" aria-hidden="true" style="display: none" />
</template>
