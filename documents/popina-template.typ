// ============================================================
// Popina — B&W minimal template for Pandoc 3.x
// ============================================================

#let black   = rgb("#1A1A1A")
#let dark    = rgb("#444444")
#let mid     = rgb("#777777")
#let light   = rgb("#AAAAAA")
#let rule-c  = rgb("#D0D0D0")

#let logo = image("popina-logo.svg", height: 9pt)
#let logo-cover = image("popina-logo.svg", height: 16pt)

// ── conf() ──────────────────────────────────────────────────
#let conf(
  title: none,
  subtitle: none,
  authors: (),
  keywords: (),
  date: none,
  lang: "fr",
  region: "FR",
  abstract-title: none,
  abstract: none,
  thanks: none,
  margin: (top: 36mm, bottom: 32mm, left: 32mm, right: 32mm),
  paper: "a4",
  font: ("Inter", "Helvetica Neue", "Helvetica", "Arial"),
  fontsize: 9.5pt,
  mathfont: (),
  codefont: (),
  linestretch: 0.78em,
  sectionnumbering: none,
  pagenumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  cols: 1,
  doc,
) = {

  let author-name = if authors.len() > 0 {
    let a = authors.first()
    if type(a) == dictionary { a.at("name", default: "") } else { a }
  } else { "" }

  // ── page ──────────────────────────────────────────────────
  set page(
    paper: paper,
    margin: margin,
    header: context {
      if counter(page).get().first() > 1 {
        v(4pt)
        grid(
          columns: (1fr, 1fr),
          align: (left + horizon, right + horizon),
          logo,
          text(fill: light, size: 6.5pt, tracking: 0.8pt,
            upper[Confidentiel]),
        )
        v(8pt)
        line(length: 100%, stroke: 0.3pt + rule-c)
      }
    },
    footer: context {
      if counter(page).get().first() > 1 {
        line(length: 100%, stroke: 0.3pt + rule-c)
        v(8pt)
        align(right,
          text(fill: light, size: 7pt)[
            #counter(page).display() / #context counter(page).final().first()
          ]
        )
      }
    },
  )

  // ── typography ────────────────────────────────────────────
  set text(font: font, size: fontsize, lang: lang, fill: black)
  set par(justify: true, leading: linestretch, first-line-indent: 0pt, spacing: 1.6em)

  // ── headings ──────────────────────────────────────────────

  // H1 : titre de section — grand, gras, page break, espace genereux
  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    v(40pt, weak: true)
    text(size: 22pt, weight: "bold", fill: black, it.body)
    v(24pt, weak: true)
  }

  // H2 : sous-section — filet fin au-dessus pour marquer la rupture
  show heading.where(level: 2): it => {
    v(32pt, weak: true)
    line(length: 100%, stroke: 0.3pt + rule-c)
    v(14pt, weak: true)
    text(size: 12pt, weight: "semibold", fill: black, it.body)
    v(10pt, weak: true)
  }

  // H3 : sous-sous-section
  show heading.where(level: 3): it => {
    v(22pt, weak: true)
    text(size: 10.5pt, weight: "semibold", fill: dark, it.body)
    v(8pt, weak: true)
  }

  // H4 : label
  show heading.where(level: 4): it => {
    v(16pt, weak: true)
    text(size: 9.5pt, weight: "medium", fill: mid,
      upper(it.body))
    v(6pt, weak: true)
  }

  // ── links ─────────────────────────────────────────────────
  show link: it => underline(offset: 2pt, stroke: 0.4pt + light, it)

  // ── blockquotes ───────────────────────────────────────────
  show quote.where(block: true): it => {
    v(8pt)
    block(
      inset: (left: 20pt, top: 0pt, bottom: 0pt),
      stroke: (left: 1.5pt + rule-c),
      width: 100%,
      text(style: "italic", fill: dark, it.body),
    )
    v(8pt)
  }

  // ── tables ────────────────────────────────────────────────
  set table(inset: (x: 10pt, y: 9pt), stroke: none)
  show figure.where(kind: table): it => {
    set text(size: 8.5pt)
    block(width: 100%, {
      set table(stroke: (bottom: 0.3pt + rule-c))
      it
    })
  }

  // ── lists — genereux en espacement ────────────────────────
  set list(marker: text(fill: mid)[--], indent: 14pt, spacing: 1.2em)
  set enum(numbering: "1.", indent: 14pt, spacing: 1.2em)

  // ── strong ────────────────────────────────────────────────
  show strong: set text(weight: "semibold")

  // ── section numbering ─────────────────────────────────────
  if sectionnumbering != none {
    set heading(numbering: sectionnumbering)
  }

  // ════════════════════════════════════════════════════════════
  //  COVER
  // ════════════════════════════════════════════════════════════
  page(margin: (top: 40mm, bottom: 40mm, left: 32mm, right: 32mm),
       header: none, footer: none)[

    #logo-cover

    #v(1fr)

    #block(width: 85%,
      text(size: 28pt, weight: "bold", fill: black)[#title]
    )

    #v(20pt)

    #if subtitle != none [
      #text(size: 12pt, weight: "regular", fill: mid)[#subtitle]
      #v(12pt)
    ]

    #v(1fr)

    #line(length: 100%, stroke: 0.3pt + rule-c)
    #v(14pt)

    #grid(
      columns: (1fr, 1fr, 1fr),
      column-gutter: 16pt,
      [
        #text(fill: light, size: 6.5pt, tracking: 0.8pt)[#upper[Auteur]]
        #v(4pt)
        #text(fill: black, size: 9pt)[#author-name]
      ],
      [
        #text(fill: light, size: 6.5pt, tracking: 0.8pt)[#upper[Date]]
        #v(4pt)
        #text(fill: black, size: 9pt)[#if date != none [#date] else [--]]
      ],
      [
        #text(fill: light, size: 6.5pt, tracking: 0.8pt)[#upper[Classification]]
        #v(4pt)
        #text(fill: black, size: 9pt)[Confidentiel]
      ],
    )

    #v(14pt)
    #line(length: 100%, stroke: 0.3pt + rule-c)
  ]

  // ════════════════════════════════════════════════════════════
  //  TOC
  // ════════════════════════════════════════════════════════════
  page[
    #v(20pt)
    #text(size: 22pt, weight: "bold", fill: black)[Sommaire]
    #v(24pt)
    #outline(title: none, indent: 1.4em, depth: 2)
  ]

  // ════════════════════════════════════════════════════════════
  //  BODY
  // ════════════════════════════════════════════════════════════
  if cols > 1 { columns(cols, doc) } else { doc }
}
