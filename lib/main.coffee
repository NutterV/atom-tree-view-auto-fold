{CompositeDisposable, Emitter} = require 'atom'
TreeViewUI = require './treeviewui'
utils = require './utils'

module.exports = TreeViewAutoFold =

  config:
    autoToggle:
      type: 'boolean'
      default: true
      description:
        'Automatically fold tree when starting atom'
    hideAllExceptOpenFiles:
      type: 'boolean'
      default: true
      description:
        'Hide all files that are not open, unless you expand the directory'
    hideAllExceptModifiedFiles:
      type: 'boolean'
      default: true
      description:
        'Hide all files that are not new/modified, unless you expand the directory'
    showOpenFileIndicator:
      type: 'boolean'
      default: true
      description:
        'Show an indicator next all open files'
    showAutoFoldedFolderIndicator:
      type: 'boolean'
      default: true
      description:
        'Show an indicator next to all directories that have folded items'

  subscriptions: null
  treeView: null
  subscriptionsOfCommands: null
  active: false
  treeViewUI: null
  emitter: null

  deactivate: ->
      @subscriptions?.dispose()
      @subscriptions = null
      @subscriptionsOfCommands?.dispose()
      @subscriptionsOfCommands = null
      @treeView = null
      @active = false
      @toggled = false
      @treeViewUI?.destruct()
      @treeViewUI = null
      @emitter?.clear()
      @emitter?.dispose()
      @emitter = null

  activate: ->
    @emitter = new Emitter
    @ignoredRepositories = new Map
    @subscriptionsOfCommands = new CompositeDisposable
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.packages.onDidActivateInitialPackages =>
      @doInitPackage()
    # Workaround for the isse that "onDidActivateInitialPackages" never gets
    # fired if one or more packages are failing to initialize
    @activateInterval = setInterval (=>
        @doInitPackage()
      ), 1000
    @doInitPackage()

  doInitPackage: ->
    # Check if the tree view has been already initialized
    treeView = @getTreeView()
    return unless treeView and not @active

    clearInterval(@activateInterval)
    @treeView = treeView
    @active = true

    # Toggle tree-view-git-status...
    @subscriptionsOfCommands.add atom.commands.add 'atom-workspace',
      'tree-view-auto-fold:toggle': =>
         @toggle()
    autoToggle = atom.config.get 'tree-view-auto-fold.autoToggle'
    @toggle() if autoToggle
    @emitter.emit 'did-activate'

  toggle: ->
    return unless @active
    if not @toggled
      @toggled = true
      @treeViewUI = new TreeViewUI @treeView
    else
      @toggled = false
      @treeViewUI?.destruct()
      @treeViewUI = null

  getTreeView: ->
    if not @treeView?
      if atom.packages.getActivePackage('tree-view')?
        treeViewPkg = atom.packages.getActivePackage('tree-view')
      # TODO Check for support of Nuclide Tree View
      if treeViewPkg?.mainModule?.treeView?
        return treeViewPkg.mainModule.treeView
      else
        return null
    else
      return @treeView

  onDidActivate: (handler) ->
    return @emitter.on 'did-activate', handler
