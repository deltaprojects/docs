React = require 'react/addons'
Immutable = require 'immutable'
Bacon = require 'baconjs'
marked = require 'marked'
_ = require 'underscore'

currentBase = null

addInfo = (id, url) -> (entry) ->
  title: entry.title
  url: entry.url
  root: url
  id: id
  sections: _.map(entry.sections || [], addInfo(id, url))

root = (id, url) ->
  Bacon.fromPromise($.ajax(url: "#{url}/toc.json"))
    .map(addInfo(id, url))
    .mapError ->
      root: url
      id: id
      title: id
      offline: true

repos = (root repo... for repo in window.REPOS)
toc = Bacon.combineAsArray repos

identFromState = (state, toc) ->
  parts = state.hash.split('?ref=')
  if parts.length > 1
    id = parts[1].split('/')[0]
    ref = parts[1].split('/')[1]
    base = _.find(toc, (t) -> t.id == id).root
    {
      base: base
      id: id
      ref: ref
    }
  else
    ref: 'index'

renderer = new marked.Renderer

renderer.link = (href, title, text) ->
  addr = if href.match(/(http|https):\/\//) then href else '?ref=' + href
  '<a href="' + addr + '">' + text + '</a>'

renderer.html = (html) ->
  console.log("output " + html)
  html

renderer.image = (href, title, text) ->
  '<center><img class="docs-image" src="' + currentBase + '/' + href + '" alt="' + title + '" /></center>'

renderer.table = (header, body) ->
  '<div class="table-responsive"><table class="table table-bordered">\n' + '<thead>\n' + header + '</thead>\n' + '<tbody>\n' + body + '</tbody>\n' + '</table></div>\n'

renderer.code = (code, lang) ->
  '<div class="highlight"><pre><code>' + hljs.highlight(lang, code).value + '</code></pre></div>'

renderer.heading = (text, level) ->
  match = text.match(/^(.+?)\s\[(.+?)\]$/)
  id = null
  if match
    id = match[2]
    text = match[1]
  if level == 1 then '<h1' + (if id then ' id="' + id + '"' else '') + ' class="page-header">' + text + '</h1>' else '<h' + level + (if id then ' id="' + id + '"' else '') + '>' + text + '</h' + level + '>'

renderer.blockquote = (body) ->
  '<div class="alert alert-warning">' + body + '</div>'

marked.setOptions
  renderer: renderer
  gfm: true
  tables: true
  breaks: false
  smartypants: false

identStream = $(window)
  .asEventStream 'statechange'
  .map History.getState
  .startWith History.getState()
  .flatMapLatest (state) ->
    toc.map (t) -> identFromState state, t

snipHighlightHtml = (code, lang) ->
  if code.indexOf("<!-- snip -->") == -1
    "```#{lang}\n#{code}\n```"
  else
    entries = code.split(/(<!-- snip -->[\S\s]*<!-- end-snip -->)/mg)
    html = '<div class="highlight"><pre><code>'
    for entry in entries
      if entry.indexOf("<!-- snip -->\n") != -1
        withoutMarkers = entry.replace("<!-- snip -->\n", "").replace("<!-- end-snip -->", "")
        html += "<span style='color:#aaa'>···</span>\n" + hljs.highlight(lang, withoutMarkers).value + "<span style='color:#aaa'>···</span>\n"
    html + '</code></pre></div>\n'

snipHighlightJson = (code, lang) ->
  entries = code.trim().split(/^$([\S\s]*)^$/mg)
  html = '<div class="highlight"><pre><code>'
  for entry in entries
    m = entry.match(/$^/mg)
    if m && m.length > 1
      withoutMarkers = "{\n" + entry.substring(1, entry.length) + "}"
      output = hljs.highlight(lang, withoutMarkers).value
      html += "<span style='color:#aaa'>···</span>\n" + output.substring(2, output.length - 1) + "<span style='color:#aaa'>···</span>\n"
  html + '</code></pre></div>\n'

snipHighlight = (code, lang) ->
  if lang == "html"
    snipHighlightHtml(code, lang)
  else if lang == "json"
    snipHighlightJson(code, lang)
  else
    "```#{lang}\n#{code}\n```\n"

streamFor = (snippet, ident) ->
  matches = snippet.match(/^\@code\((.+)\) (.+?)$/)
  if matches
    [ignore, lang, filename] = matches
    url = "#{ident.base}/#{filename}"
    (Bacon.fromPromise $.ajax(url: url, dataType: "text")).map (code) ->
      button = """
               <p><button type="button" class="btn btn-default btn-xs" onclick="window.open('#{url}', '_blank')">
                 <span class="glyphicon glyphicon-eye-open" aria-hidden="true"></span> View example
               </button></p>
               """
      """
      #{snipHighlight(code, lang)}
      #{if lang == "html" then button else ""}
      """
  else
    Bacon.constant(snippet)

includeCode = (markdown, ident) ->
  (Bacon.combineAsArray (streamFor e, ident for e in markdown.split(/^(@code.*)$/m))).map (vs) -> vs.join("")

identStream.flatMapLatest (ident) ->
    withoutHash = ident.ref.split('#')[0]
    (Bacon.fromPromise $.ajax(url: if ident.base then ident.base + '/' + withoutHash + '.md' else 'index.md')).flatMapLatest (code) ->
      includeCode(code, ident)
  .mapError ->
    "<div class='alert alert-warning' role='alert'><span class='glyphicon glyphicon-question-sign'></span> Currently not available.</span></div>"
  .map marked
  .onValue (html) ->
    document.getElementById("contents").innerHTML = html

tocTree = Bacon.combineAsArray(toc, identStream).map (v) ->
  [tree, ident] = v
  _.each tree, (t) ->
    t.active = false
    if ident.id == t.id
      currentBase = ident.base
      childIsActive = false
      _.each t.sections, (s) ->
        s.active = s.url == ident.ref
        childIsActive = childIsActive or s.active
        return
      t.active = t.url == ident.ref or childIsActive
  tree

TOCEntry = React.createClass
  click: ->
    unless @props.offline
      History.pushState null, null, '?ref=' + @props.id + '/' + @props.url
  render: ->
    entries = (<TOCEntry {...entry} /> for entry in @props.sections || [])
    classes = React.addons.classSet
      'active': @props.active

    link = if @props.offline
      <a onClick={@click}>
        <span className="glyphicon glyphicon-remove" aria-hidden="true"></span>
        {@props.title} offline
      </a>
    else
      <a onClick={@click}>{@props.title}</a>

    <li className={classes}>{link}
      <ul className="nav nav-stacked">
        {entries}
      </ul>
    </li>

TableOfContents = React.createClass
  render: ->
    entries = (<TOCEntry {...entry} /> for entry in @props.entries)
    <ul className="nav nav-stacked fixed">
      {entries}
    </ul>

tocTree.onValue (toc) ->
  React.render <TableOfContents entries={toc} />, document.getElementById "toc"
