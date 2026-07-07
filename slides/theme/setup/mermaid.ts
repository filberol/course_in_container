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
