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

renderer.image = (href, title, text) ->
  '<center><img class="docs-image" src="' + currentBase + '/' + href + '" alt="' + title + '" /></center>'

renderer.table = (header, body) ->
  '<div class="table-responsive"><table class="table table-striped table-bordered">\n' + '<thead>\n' + header + '</thead>\n' + '<tbody>\n' + body + '</tbody>\n' + '</table></div>\n'

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
  smartypants: true

identStream = $(window)
  .asEventStream 'statechange'
  .map History.getState
  .startWith History.getState()
  .flatMapLatest (state) ->
    toc.map (t) -> identFromState state, t

identStream.flatMapLatest (ident) ->
    withoutHash = ident.ref.split('#')[0]
    Bacon.fromPromise $.ajax(url: if ident.base then ident.base + '/' + withoutHash + '.md' else 'index.md')
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
    unless @props.entry.offline
      History.pushState null, null, '?ref=' + @props.entry.id + '/' + @props.entry.url
  render: ->
    entries = (<TOCEntry entry={entry} /> for entry in @props.entry.sections || [])
    classes = React.addons.classSet
      'active': @props.entry.active

    link = if @props.entry.offline
      <a onClick={@click}>
        <span className="glyphicon glyphicon-remove" aria-hidden="true"></span>
        {@props.entry.title} offline
      </a>
    else
      <a onClick={@click}>{@props.entry.title}</a>

    <li className={classes}>{link}
      <ul className="nav nav-stacked">
        {entries}
      </ul>
    </li>

TableOfContents = React.createClass
  render: ->
    entries = (<TOCEntry entry={entry} /> for entry in @props.entries)
    <ul className="nav nav-stacked fixed">
      {entries}
    </ul>

tocTree.onValue (toc) ->
  React.render <TableOfContents entries={toc} />, document.getElementById "toc"
