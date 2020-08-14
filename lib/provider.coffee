fs = require 'fs-plus'
glob = require 'glob'
path = require 'path'
escapeStringRegexp = require 'escape-string-regexp'

module.exports =
class LinkProvider
  selector: '.source.gfm'
  filterSuggestions: true

  getSuggestions: ({editor, bufferPosition}) ->
    prefix = @getPrefix(editor, bufferPosition)
    return unless prefix[0] is atom.config.get('wikilink.linkbegin')[0]
    new Promise (resolve) ->
      suggestions = []

      filePath = editor?.buffer?.file?.path
      if not filePath
        resolve(suggestions)

      linkResolution = atom.config.get('wikilink.linkresolution')

      if linkResolution is 'project'
        [projPath, relPath] = atom.project.relativizePath(filePath)
        if not projPath
          resolve(suggestions)

        noteDirectory = fs.normalize(projPath)
      else if linkResolution is 'file'
        noteDirectory = path.dirname(filePath)

      noteExtension = atom.config.get('wikilink.extension')
      noteGlob = "**/*" + noteExtension
      notes = glob.sync(noteGlob, {cwd: noteDirectory})

      for note in notes
        note = note.replace noteExtension, ""
        suggestions.push
          text: note

      resolve(suggestions)

  getPrefix: (editor, bufferPosition) ->
      # The prefix regex
      buildRegex = escapeStringRegexp(atom.config.get('wikilink.linkbegin'))
      buildRegex += '[\\w\\s0-9_-]+$'
      regex = new RegExp(buildRegex)

      # Get the text for the line up to the triggered buffer position
      line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])

      # Match the regex to the line, and return the match
      line.match(regex)?[0] or ''
