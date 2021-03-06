{CompositeDisposable} = require 'atom'
path = require 'path'
utils = require './utils'

module.exports = class TreeViewUI

  subscriptions: null
  entriesToKeepVisible: null
  hideAllExceptOpenFiles: null
  hideAllExceptModifiedFiles: null
  showOpenFileIndicator: null
  showAutoFoldedFolderIndicator: null
  pathsToIgnore: null
  treeViewMaster: null

  constructor: (@treeView) ->
    # Read configuration
    @hideAllExceptOpenFiles =
      atom.config.get 'tree-view-auto-fold.hideAllExceptOpenFiles'
    @hideAllExceptModifiedFiles =
      atom.config.get 'tree-view-auto-fold.hideAllExceptModifiedFiles'
    @showOpenFileIndicator =
      atom.config.get 'tree-view-auto-fold.showOpenFileIndicator'
    @showAutoFoldedFolderIndicator =
      atom.config.get 'tree-view-auto-fold.showAutoFoldedFolderIndicator'

    @subscriptions = new CompositeDisposable
    @entriesToKeepVisible = []
    @pathsToIgnore = []

    @treeViewMaster = @treeView

    # Bind against events which are causing an update of the tree view
    @subscribeUpdateConfigurations()
    @subscribeUpdateTreeView()
    @handleEvents()

    # Trigger inital update of all root nodes
    @updateRoots()

  destruct: ->
    @subscriptions?.dispose()
    @subscriptions = null
    document.getElementsByClassName('tool-panel')[0].removeEventListener 'click', ((e) =>
      # This prevents accidental collapsing when a .entries element is the event target
      return if e.target.classList.contains('entries')
      @entryClicked(e) unless e.shiftKey or e.metaKey or e.ctrlKey
    ), true
    @treeViewMaster.updateRoots()
    @treeViewMaster = null
    @pathsToIgnore = null
    @entriesToKeepVisible = null
    @hideAllExceptOpenFiles = null
    @hideAllExceptModifiedFiles = null
    @showOpenFileIndicator = null
    @showAutoFoldedFolderIndicator = null

  handleEvents: ->
    document.getElementsByClassName('tool-panel')[0].addEventListener 'click', ((e) =>
      # This prevents accidental collapsing when a .entries element is the event target
      return if e.target.classList.contains('entries')
      @entryClicked(e) unless e.shiftKey or e.metaKey or e.ctrlKey
    ), true

  subscribeUpdateTreeView: ->
    @subscriptions.add(
      atom.project.onDidChangePaths (projectPaths) =>
        @updateRoots()
    )
    @subscriptions.add(
      atom.workspace.onDidChangeActivePaneItem (paneItem) =>
        @updateRoots()
    )
    @subscriptions.add(
      atom.workspace.observeTextEditors (editor) =>
        editor.onDidDestroy =>
          try
            path = editor?.buffer.file?.path
            @pathsToIgnore.push(path)
            @populateFilterEntries()
            @updateRoots false
          catch error
          @updateRoots()
    )
    @subscriptions.add(
      atom.config.onDidChange 'tree-view.hideVcsIgnoredFiles', =>
        @updateRoots()
    )
    @subscriptions.add(
      atom.config.onDidChange 'tree-view.hideIgnoredNames', =>
        @updateRoots()
    )
    @subscriptions.add(
      atom.config.onDidChange 'core.ignoredNames', =>
        @updateRoots() if atom.config.get 'tree-view.hideIgnoredNames'
    )
    @subscriptions.add(
      atom.config.onDidChange 'tree-view.sortFoldersBeforeFiles', =>
        @updateRoots()
    )

  subscribeUpdateConfigurations: ->
    @subscriptions.add(
      atom.config.observe 'tree-view-auto-fold.hideAllExceptOpenFiles',
        (newValue) =>
          if @hideAllExceptOpenFiles isnt newValue
            @hideAllExceptOpenFiles = newValue
            @updateRoots()
    )
    @subscriptions.add(
      atom.config.observe 'tree-view-auto-fold.hideAllExceptModifiedFiles',
        (newValue) =>
          if @hideAllExceptModifiedFiles isnt newValue
            @hideAllExceptModifiedFiles = newValue
          @updateRoots()
    )
    @subscriptions.add(
      atom.config.observe 'tree-view-auto-fold.showOpenFileIndicator',
        (newValue) =>
          if @showOpenFileIndicator isnt newValue
            @showOpenFileIndicator = newValue
          @updateRoots()
    )
    @subscriptions.add(
      atom.config.observe 'tree-view-auto-fold.showAutoFoldedFolderIndicator',
        (newValue) =>
          if @showAutoFoldedFolderIndicator isnt newValue
            @showAutoFoldedFolderIndicator = newValue
          @updateRoots()
    )

  populateFilterEntries: () ->
    @entriesToKeepVisible = []
    return unless @hideAllExceptOpenFiles

    if @hideAllExceptOpenFiles
      for editor in atom.workspace.getTextEditors()
        path = editor?.buffer.file?.path
        @addFileSegmentsToExceptions(path) unless @pathsToIgnore.includes(path)

  addFileSegmentsToExceptions: (pathToSegmentize) ->
    if path?
      for path in utils.allPathSegments pathToSegmentize
        if not @entriesToKeepVisible.includes(path)
          @entriesToKeepVisible.push(path)

  entryClicked: (e) ->
    if entry = e.target.closest('.entry')
      if entry.classList.contains('directory')
        e.stopImmediatePropagation()
        @unhideData entry
      else
        if entry.classList.contains('file')
          @populateFilterEntries()
          @addFileSegmentsToExceptions entry.getPath()
          @updateRoots false

  unhideData: (entry) ->
    if entry.classList.contains('hiddenData')
      if entry.classList.contains('collapsed') or entry.children[0].classList.contains('autofolded')
        @swapClass entry, 'collapsed', 'expanded'
        for child in entry.children[1].querySelectorAll('.entry')
          @removeClass child, 'hiddenEntry'
          if child.classList.contains('directory')
            @removeClass child.children[0], 'autofolded'
        @removeClass entry.children[0], 'autofolded'
      else
        @updateRoots entry
    else
      if entry.classList.contains('collapsed')
        entry.expand(false)
        @swapClass entry, 'collapsed', 'expanded'
      else
        @swapClass entry, 'expanded', 'collapsed'
    atom.commands.dispatch(atom.views.getView(atom.workspace), "tree-view:show")

  addDataClassToParentFolder: (entry, classToAdd) ->
    parent = entry.parentNode.parentNode
    if parent.classList.contains('directory')
      parent.classList.add(classToAdd)
      if classToAdd == 'hiddenData' and
        @showAutoFoldedFolderIndicator and
        parent.classList.contains('expanded')
          parent.children[0].classList.add('autofolded')
      @addDataClassToParentFolder parent, classToAdd

  removeAllAddedClasses: (parent=@treeViewMaster.list) ->
    @removeHeaderClasses parent
    try
      for entry in parent.querySelectorAll('.entry')
        @removeClass entry, 'open'
        @removeClass entry, 'hiddenData'
        @removeClass entry, 'hiddenEntry'
    catch error
      console.log parent.toString()

  removeHeaderClasses: (parent=@treeViewMaster.list) ->
    try
      for header in parent.querySelectorAll('.header')
        @removeClass header, 'autofolded'
    catch error
      console.log parent.toString()

  removeClass: (item, classToRemove) ->
    item.classList.remove(classToRemove) if item.classList.contains(classToRemove)

  swapClass: (item, classToRemove, classToAdd) ->
    if item.classList.contains(classToRemove)
      @removeClass item, classToRemove
      item.classList.add(classToAdd)

  updateRoots: (parent=@treeViewMaster.list, reset=true) ->
    @pathsToIgnore = [] if reset
    @populateFilterEntries() if reset
    ents = @entriesToKeepVisible
    if @hideAllExceptOpenFiles or @hideAllExceptModifiedFiles
      @removeAllAddedClasses parent
      try
        for entry in parent.querySelectorAll('.file')
          if @hideAllExceptOpenFiles and
            @entriesToKeepVisible.includes(utils.normalizePath entry.getPath())
              if @showOpenFileIndicator
                entry.classList.add('open')
                @addDataClassToParentFolder entry, 'openFiles'
              continue
          if @hideAllExceptModifiedFiles and
            (entry.classList.contains('status-added') or
            entry.classList.contains('status-modified'))
              continue
          entry.classList.add('hiddenEntry')
          @addDataClassToParentFolder entry, 'hiddenData'

        for entry in parent.querySelectorAll?('.directory')
          if entry.classList.contains('project-root')
            continue
          if entry.classList.contains('collapsed')
            if @hideAllExceptOpenFiles and
              @entriesToKeepVisible.includes(utils.normalizePath entry.getPath())
                continue
            if @hideAllExceptModifiedFiles and
              (entry.classList.contains('status-added') or
              entry.classList.contains('status-modified'))
                continue
            entry.classList.add('hiddenEntry')
            @addDataClassToParentFolder entry, 'hiddenData'
          else
            children = entry.querySelectorAll('.file').length
            hiddenChildren = entry.querySelectorAll('.hiddenEntry').length
            if children == hiddenChildren
              @swapClass entry, 'expanded', 'collapsed'
      catch error
        console.log parent.toString()
