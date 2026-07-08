import { defineMermaidSetup } from '@slidev/types'

export default defineMermaidSetup(() => ({
  theme: 'base',
  themeVariables: {
    fontFamily: '"Golos Text", "Segoe UI", sans-serif',
    fontSize: '15px',

    // flowchart / generic
    primaryColor: '#edf4ff',
    primaryTextColor: '#06214f',
    primaryBorderColor: '#0b68fe',
    lineColor: '#0a4fc2',
    secondaryColor: '#dff7ff',
    secondaryBorderColor: '#00ccff',
    secondaryTextColor: '#06214f',
    tertiaryColor: '#ffffff',
    tertiaryBorderColor: '#c9ddff',
    tertiaryTextColor: '#16263d',
    clusterBkg: '#f5f9ff',
    clusterBorder: '#c9ddff',
    edgeLabelBackground: '#ffffff',
    titleColor: '#06214f',

    // sequence diagrams
    actorBkg: '#edf4ff',
    actorBorder: '#0b68fe',
    actorTextColor: '#06214f',
    actorLineColor: '#7d93b8',
    signalColor: '#0a4fc2',
    signalTextColor: '#16263d',
    labelBoxBkgColor: '#edf4ff',
    labelBoxBorderColor: '#0b68fe',
    labelTextColor: '#06214f',
    loopTextColor: '#06214f',
    activationBkgColor: '#dff7ff',
    activationBorderColor: '#00ccff',
    noteBkgColor: '#fff8e1',
    noteBorderColor: '#ffcc33',
    noteTextColor: '#16263d',
    sequenceNumberColor: '#ffffff',

    // state / class
    labelColor: '#06214f',
    altBackground: '#f5f9ff',

    // pie
    pie1: '#0b68fe',
    pie2: '#00ccff',
    pie3: '#0a4fc2',
    pie4: '#7f00ff',
    pie5: '#ffcc33',
    pie6: '#f93f37',
    pie7: '#06214f',
    pie8: '#c9ddff',
    pieTitleTextColor: '#06214f',
    pieLegendTextColor: '#16263d',

    // timeline / mindmap colour scales
    cScale0: '#0b68fe',
    cScale1: '#0a4fc2',
    cScale2: '#00ccff',
    cScale3: '#06214f',
    cScale4: '#7f00ff',
    cScale5: '#3f8cff',
    cScaleLabel0: '#ffffff',
    cScaleLabel1: '#ffffff',
    cScaleLabel2: '#06214f',
    cScaleLabel3: '#ffffff',
    cScaleLabel4: '#ffffff',
    cScaleLabel5: '#ffffff',
  },
  // themeCSS is baked into every rendered diagram's <svg> by Mermaid itself, so
  // it applies everywhere — interactive SPA and PDF/PNG export alike (unlike
  // theme JS, which does not run during export). We use it to (1) round node
  // shapes to match the theme and (2) make the root <svg> fill its host box so
  // the diagram scales (via its viewBox) to the space the layout gives it.
  themeCSS: `
    .node rect, .node circle, rect.actor, .actor > rect, g.classGroup rect,
    .entityBox, .attributeBoxOdd, .attributeBoxEven, .note, rect.note,
    .labelBox, .stateGroup rect, .er .entityBox { rx: 6px; ry: 6px; }
    .cluster rect { rx: 11px; ry: 11px; }
    svg { width: 100% !important; height: 100% !important; max-width: 100% !important; }
  `,
  flowchart: {
    curve: 'basis',
    htmlLabels: true,
    padding: 10,
  },
  sequence: {
    mirrorActors: false,
    actorMargin: 42,
    boxMargin: 8,
  },
}))
