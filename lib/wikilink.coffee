fs = require 'fs-plus'
path = require 'path'
{CompositeDisposable, Disposable} = require 'atom'
escapeStringRegexp = require 'escape-string-regexp'

module.exports = atomWikiLink =
  config:
    extension:
      title: 'Note Extension'
      description: 'The extension used for newly created notes'
      type: 'string'
      default: '.md'
      items:
        type: 'string'
    linkbegin:
      title: 'Link Begin Symbol'
      description: 'The symbol used to mark the beginning of a link'
      type: 'string'
      default: '[['
    linkend:
      title: 'Link End Symbol'
      description: 'The symbol used to mark the ending of a link'
      type: 'string'
      default: ']]'
    linkregex:
      title: 'Link Regex'
      description: 'The regex used to identify the contents of a link'
      type: 'string'
      default: '(.+)'
    linkresolution:
      title: 'Link Resolution'
      description: 'The method used to resolve links'
      type: 'string'
      default: 'project'
      enum: [
        {value: 'project', description: 'Links are resolved relative to the root project folders'}
        {value: 'file', description: 'Links are resolved relative to the current file'}
      ]
  subscriptions: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace', 'wikilink:follow': => @follow()
    @subscriptions.add atom.commands.add 'atom-workspace', 'wikilink:copy-link': => @copyLink()

    addEventListener = (editor, eventName, handler) ->
      editorView = atom.views.getView(editor)
      editorView.addEventListener eventName, handler
      new Disposable ->
        editorView.removeEventListener eventName, handler

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      disposables = new CompositeDisposable
      disposables.add addEventListener editor, 'click', (event) =>
        if event.altKey
          @follow()
      disposables.add editor.onDidDestroy =>
        disposables.dispose()
        @subscriptions.remove(disposables)
      @subscriptions.add(disposables)

  deactivate: ->
    @subscriptions.dispose()

  follow: ->
    editor = atom.workspace.getActiveTextEditor()
    if not editor
      console.log('An editor window must be active before you can follow a link.')
      return

    filePath = editor.buffer?.file?.path
    if not filePath
      console.log('You must save the file before you can follow a link.')
      return

    linkResolution = atom.config.get('wikilink.linkresolution')

    if linkResolution is 'project'
      [projPath, relPath] = atom.project.relativizePath(filePath)
      if not projPath
        console.log('The file is not saved in a project folder.')
        return

      noteDirectory = fs.normalize(projPath)
    else if linkResolution is 'file'
      noteDirectory = path.dirname(filePath)

    noteExtension = atom.config.get('wikilink.extension')
    cursorPosition = editor.getCursorBufferPosition()
    buffer = editor.getBuffer()
    currentRow = buffer.lineForRow(cursorPosition.row)
    linkRegex = escapeStringRegexp(atom.config.get('wikilink.linkbegin'))
    linkRegex += atom.config.get('wikilink.linkregex')
    linkRegex += escapeStringRegexp(atom.config.get('wikilink.linkend'))
    pattern = new RegExp(linkRegex, 'g')
    match = pattern.exec currentRow
    return unless match
    matches = true
    while match
      return if cursorPosition.column < match.index
      if cursorPosition.column < (match.index + match[0].length)
        noteName = match[1]
        notePath = path.join(noteDirectory, noteName + noteExtension)
        unless fs.existsSync(notePath)
          fs.writeFileSync(notePath, '')
        atom.workspace.open(notePath)
        return
      else
        match = pattern.exec currentRow

  copyLink: ->
    editor = atom.workspace.getActiveTextEditor()
    if not editor
      console.log('An editor window must be active before you can copy a link.')
      return

    filePath = editor.buffer?.file?.path
    if not filePath
      console.log('You must save the file before you can copy a link to it.')
      return

    noteExtension = atom.config.get('wikilink.extension')
    linkBegin = atom.config.get('wikilink.linkbegin')
    linkEnd = atom.config.get('wikilink.linkend')
    linkResolution = atom.config.get('wikilink.linkresolution')

    if linkResolution is 'project'
      [projPath, relPath] = atom.project.relativizePath(filePath)
      if not relPath
        console.log('The file must be saved in a project folder before you can copy a link to it.')
        return
    else if linkResolution is 'file'
      relPath = path.basename(filePath)

    text = relPath.replace noteExtension, ""
    text = linkBegin + text + linkEnd
    atom.clipboard.write(text)

  provide: ->
    unless @provider?
      LinkProvider = require('./provider')
      @provider = new LinkProvider()

    @provider
